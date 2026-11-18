#!/usr/bin/env bash
set -euo pipefail

# 0. Parameter laden
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/params.sh"

echo "=========================================================="
echo "   MAXIMALE KOSTENSENKUNG (Pause & Zero-Compute/Zero-Bastion)"
echo "=========================================================="

# 1. VMs deallokieren (Stoppt alle VM Compute-Kosten)
echo "-> 1/3: Deallokiere VMs (Rechenkosten fallen auf 0 €)..."
az vm deallocate --resource-group "$RG" --name "app-vm" --no-wait
az vm deallocate --resource-group "$RG" --name "db-vm" --no-wait

echo "   Warte auf Abschluss der Deallokation..."
while az vm list -g "$RG" -d --query "[?powerState!='VM deallocated']" -o tsv | grep -q .; do
  sleep 5
done
echo "   [OK] app-vm und db-vm sind deallokiert."

# 2. Azure Bastion Host entfernen (Größter Kostentreiber: spart ~0,19 €/Std. bzw. ~140 €/Monat)
echo -e "\n-> 2/3: Entferne Bastion Host (spart ~140 €/Monat)..."
if az network bastion show -g "$RG" -n "bastion-host" >/dev/null 2>&1; then
  az network bastion delete --resource-group "$RG" --name "bastion-host" --yes --no-wait
  echo "   [OK] Löschung von bastion-host im Hintergrund angestoßen."
  echo "   Hinweis: Subnetz (AzureBastionSubnet) und Public IP (bastion-pip) bleiben erhalten."
else
  echo "   [INFO] Kein aktiver Bastion Host vorhanden (bereits entfernt)."
fi

# 3. Disks auf Standard_LRS (günstigste Storage-Klasse) herabstufen
echo -e "\n-> 3/3: Ändere OS-Disks auf günstigste Storage-Klasse (Standard_LRS)..."
APP_DISK=$(az vm show -g "$RG" -n "app-vm" --query "storageProfile.osDisk.name" -o tsv)
DB_DISK=$(az vm show -g "$RG" -n "db-vm" --query "storageProfile.osDisk.name" -o tsv)

if [ -n "$APP_DISK" ]; then
  az disk update -g "$RG" -n "$APP_DISK" --sku "Standard_LRS" --no-wait >/dev/null
  echo "   [OK] app-vm Disk ($APP_DISK) auf Standard_LRS umgestellt."
fi

if [ -n "$DB_DISK" ]; then
  az disk update -g "$RG" -n "$DB_DISK" --sku "Standard_LRS" --no-wait >/dev/null
  echo "   [OK] db-vm Disk ($DB_DISK) auf Standard_LRS umgestellt."
fi

echo -e "\n=========================================================="
echo "   ALLE KOSTENFAKTOREN IM LEERLAUF MINIMIERT:             "
echo "   ✅ VM-Compute: 0,00 €                                 "
echo "   ✅ Bastion-Host: 0,00 € (spart ~0,19 €/Std.)          "
echo "   ✅ Storage: Minimiert auf Standard_LRS (wenige Cents)  "
echo "   Mit ./start_vms.sh werden alle Komponenten reaktiviert."
echo "=========================================================="
