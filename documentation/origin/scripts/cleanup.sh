#!/usr/bin/env bash
set -euo pipefail

# 0. Parameter laden
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/params.sh"

echo "=========================================================="
echo "   ⚠️  AZURE RESOURCE CLEANUP"
echo "=========================================================="
echo "Ziel-Resource-Group: ${RG}"

# Bestätigung abfragen, sofern nicht mit -y/--yes aufgerufen
FORCE=false
if [[ "${1:-}" == "-y" || "${1:-}" == "--yes" ]]; then
  FORCE=true
fi

if [ "$FORCE" = false ]; then
  read -p "Möchtest du die gesamte Resource Group '${RG}' und ALLE darin enthaltenen Ressourcen unwiderruflich löschen? (j/N): " -r CONFIRM
  if [[ ! "$CONFIRM" =~ ^[jJyY]$ ]]; then
    echo "Abbruch durch Benutzer. Es wurden keine Ressourcen gelöscht."
    exit 0
  fi
fi

echo -e "\n-> Überprüfe Existenz der Resource Group '${RG}'..."
if az group exists --name "$RG" | grep -q "true"; then
  echo "-> Lösche Resource Group '${RG}' und alle enthaltenen Ressourcen..."
  az group delete --name "$RG" --yes --no-wait
  echo -e "\n=========================================================="
  echo "   [ERFOLG] Löschvorgang für '${RG}' wurde im Hintergrund angestoßen."
  echo "   Alle Ressourcen (VMs, Bastion, VNet, Disks, Public IPs) werden rückstandslos entfernt."
  echo "   Alle laufenden Kosten stoppen vollständig."
  echo "=========================================================="
else
  echo "[INFO] Resource Group '${RG}' existiert nicht (bereits gelöscht)."
fi
