#!/usr/bin/env bash
set -euo pipefail

# 0. Parameter laden
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/params.sh"

echo "=========================================================="
echo "   REAKTIVIERE INFRASTRUKTUR (Disks, VMs & Bastion)"
echo "=========================================================="

# 1. Disks wieder auf Hochleistungs-Storage (Premium_LRS) hochstufen
echo "-> 1/3: Setze OS-Disks wieder auf Premium_LRS..."
APP_DISK=$(az vm show -g "$RG" -n "app-vm" --query "storageProfile.osDisk.name" -o tsv)
DB_DISK=$(az vm show -g "$RG" -n "db-vm" --query "storageProfile.osDisk.name" -o tsv)

if [ -n "$APP_DISK" ]; then
  az disk update -g "$RG" -n "$APP_DISK" --sku "Premium_LRS" >/dev/null
  echo "   [OK] app-vm Disk ($APP_DISK) auf Premium_LRS gesetzt."
fi

if [ -n "$DB_DISK" ]; then
  az disk update -g "$RG" -n "$DB_DISK" --sku "Premium_LRS" >/dev/null
  echo "   [OK] db-vm Disk ($DB_DISK) auf Premium_LRS gesetzt."
fi

# 2. VMs starten
echo -e "\n-> 2/3: Starte db-vm und app-vm..."
az vm start --resource-group "$RG" --name "db-vm" --no-wait
az vm start --resource-group "$RG" --name "app-vm" --no-wait

echo "   Warte bis VMs laufen..."
while az vm list -g "$RG" -d --query "[?powerState!='VM running']" -o tsv | grep -q .; do
  sleep 5
done
echo "   [OK] Beide VMs laufen wieder."

# 3. Bastion Host prüfen und bei Bedarf im Hintergrund neu erstellen
echo -e "\n-> 3/3: Prüfe Bastion Host..."
if ! az network bastion show -g "$RG" -n "bastion-host" >/dev/null 2>&1; then
  echo "   Bastion Host nicht vorhanden. Erstelle 'bastion-host' neu im Hintergrund (--no-wait)..."
  az network bastion create \
    --resource-group "$RG" \
    --name "bastion-host" \
    --vnet-name "$VNET" \
    --public-ip-address "bastion-pip" \
    --sku Standard \
    --enable-tunneling true \
    --location "$REGION" \
    --no-wait
  echo "   [OK] Bastion-Bereitstellung läuft im Hintergrund (VMs sind sofort einsatzbereit)."
else
  echo "   [OK] Bastion Host ist bereits aktiv."
fi

# 4. Statusanzeige
echo -e "\n=== Aktueller Status der VMs ==="
az vm list -g "$RG" -d --query "[].{VM:name, PowerState:powerState, PrivateIP:privateIps, PublicIP:publicIps}" -o table

APP_PUBLIC_IP=$(az vm list-ip-addresses -g "$RG" -n "app-vm" --query "[0].virtualMachine.network.publicIpAddresses[0].ipAddress" -o tsv 2>/dev/null || echo "")

echo -e "\n=========================================================="
echo "   Infrastruktur erfolgreich reaktiviert!"
if [ -n "$APP_PUBLIC_IP" ]; then
  echo "   Swagger UI erreichbar unter: http://${APP_PUBLIC_IP}/docs"
fi
echo "=========================================================="
