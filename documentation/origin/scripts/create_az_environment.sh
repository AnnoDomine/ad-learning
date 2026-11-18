#!/usr/bin/env bash
set -euo pipefail

# 0. Parameter laden
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if [ -f "${SCRIPT_DIR}/params.sh" ]; then
  source "${SCRIPT_DIR}/params.sh"
else
  export RG="learningsteps-lab-rg"
  export REGION="germanywestcentral"
  export VNET="learningsteps-vnet"
fi

ADMIN_USERNAME="${ADMIN_USERNAME:-azureuser}"
VM_SIZE="${VM_SIZE:-Standard_D2s_v6}"
VM_IMAGE="${VM_IMAGE:-Ubuntu2204}"

# 1. Resource Group & VNet
echo "=== 1. Create Resource Group & VNet ==="
echo "=== 1.1 Create Resource Group ==="
az group create \
  --name "$RG" \
  --location "$REGION"

echo "=== 1.2 Create VNet ==="
az network vnet create \
  --resource-group "$RG" \
  --name "$VNET" \
  --location "$REGION" \
  --address-prefixes 10.0.0.0/16

# 2. Create Bastion (Standard SKU)
echo "=== 2. Create Bastion (Standard SKU) ==="
echo "=== 2.1 Create VNET Subnet ==="
az network vnet subnet create \
  --resource-group "$RG" \
  --vnet-name "$VNET" \
  --name "AzureBastionSubnet" \
  --address-prefixes 10.0.0.0/26

echo "=== 2.2 Create Public IP ==="
az network public-ip create \
  --resource-group "$RG" \
  --name "bastion-pip" \
  --location "$REGION" \
  --sku Standard \
  --allocation-method Static

echo "=== 2.3 Create Bastion ==="
az network bastion create \
  --resource-group "$RG" \
  --name "bastion-host" \
  --vnet-name "$VNET" \
  --public-ip-address "bastion-pip" \
  --sku Standard \
  --location "$REGION"

# 3. For each ["app", "db"] create Subnet, VM and store IDs
echo "=== 3. Subnets & VMs for ['app', 'db'] ==="
declare -A SUBNETS=(
  ["app"]="10.0.1.0/24"
  ["db"]="10.0.2.0/24"
)

for name in "app" "db"; do
  subnet_name="${name}-sn"
  vm_name="${name}-vm"
  prefix="${SUBNETS[$name]}"

  # 3.1 Create subnet "<name>-sn"
  echo "--- 3.1 Creating Subnet ${subnet_name} (${prefix}) ---"
  az network vnet subnet create \
    --resource-group "$RG" \
    --vnet-name "$VNET" \
    --name "$subnet_name" \
    --address-prefixes "$prefix"

  # 3.2 Create VM "<name>-vm"
  echo "--- 3.2 Creating VM ${vm_name} ---"
  if [ "$name" == "app" ]; then
    # App-VM mit Public IP (für Webzugriff) - keine redundante NIC-NSG
    az vm create \
      --resource-group "$RG" \
      --name "$vm_name" \
      --vnet-name "$VNET" \
      --subnet "$subnet_name" \
      --image "$VM_IMAGE" \
      --size "$VM_SIZE" \
      --admin-username "$ADMIN_USERNAME" \
      --generate-ssh-keys \
      --public-ip-address "${name}-pip" \
      --public-ip-sku Standard \
      --nsg ""
  else
    # DB-VM ohne Public IP (rein privat) - keine redundante NIC-NSG
    az vm create \
      --resource-group "$RG" \
      --name "$vm_name" \
      --vnet-name "$VNET" \
      --subnet "$subnet_name" \
      --image "$VM_IMAGE" \
      --size "$VM_SIZE" \
      --admin-username "$ADMIN_USERNAME" \
      --generate-ssh-keys \
      --public-ip-address "" \
      --nsg ""
  fi

  # 3.3 Store infos in env variables "<name>-ID"
  vm_id=$(az vm show --resource-group "$RG" --name "$vm_name" --query id -o tsv)
  var_name="$(echo "${name}" | tr '[:lower:]' '[:upper:]')_ID"
  export "${var_name}=${vm_id}"
  echo "--- 3.3 Stored ${var_name}=${vm_id} ---"
done

# 4. Secure Subnets with NSGs
echo "=== 4. Secure Subnets (NSGs) ==="

# 4.1 NSG für APP (Port 80 Inbound erlauben)
echo "=== 4.1 NSGs App ==="
az network nsg create \
  --resource-group "$RG" \
  --name "app-nsg" \
  --location "$REGION"

echo "=== 4.2 Rules App ==="
az network nsg rule create \
  --resource-group "$RG" \
  --nsg-name "app-nsg" \
  --name "Allow-HTTP-80" \
  --priority 100 \
  --direction Inbound \
  --access Allow \
  --protocol Tcp \
  --source-address-prefixes Internet \
  --source-port-ranges "*" \
  --destination-address-prefixes "*" \
  --destination-port-ranges 80

echo "=== 4.1 Update VNET Subnet App ==="
az network vnet subnet update \
  --resource-group "$RG" \
  --vnet-name "$VNET" \
  --name "app-sn" \
  --network-security-group "app-nsg"

# 4.2 NSG für DB (Port 5432 nur aus APP-Subnetz erlauben)
echo "=== 4.1 NSGs DB ==="
az network nsg create \
  --resource-group "$RG" \
  --name "db-nsg" \
  --location "$REGION"

echo "=== 4.2 Rules DB ==="
az network nsg rule create \
  --resource-group "$RG" \
  --nsg-name "db-nsg" \
  --name "Allow-Postgres-From-AppSN" \
  --priority 100 \
  --direction Inbound \
  --access Allow \
  --protocol Tcp \
  --source-address-prefixes "${SUBNETS[app]}" \
  --source-port-ranges "*" \
  --destination-address-prefixes "*" \
  --destination-port-ranges 5432

echo "=== 4.1 Update VNET Subnet DB ==="
az network vnet subnet update \
  --resource-group "$RG" \
  --vnet-name "$VNET" \
  --name "db-sn" \
  --network-security-group "db-nsg"

# 5. Install Software
echo "=== 5. Software Installation ==="
echo "--- Installing Python on app-vm ---"
az vm run-command invoke \
  --resource-group "$RG" \
  --name "app-vm" \
  --command-id RunShellScript \
  --scripts "export DEBIAN_FRONTEND=noninteractive; dpkg --configure -a; apt-get update && apt-get install -y python3 python3-pip python3-venv git"

echo "--- Installing PostgreSQL on db-vm ---"
az vm run-command invoke \
  --resource-group "$RG" \
  --name "db-vm" \
  --command-id RunShellScript \
  --scripts "export DEBIAN_FRONTEND=noninteractive; dpkg --configure -a; apt-get update && apt-get install -y postgresql postgresql-contrib"

echo "=== Setup Completed Successfully! ==="
