#!/usr/bin/env bash
set -euo pipefail

# Parameter laden
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/params.sh"

echo "============================================="
echo "   Azure Connectivity & Security Check"
echo "============================================="

# 1. IP-Adressen ermitteln
echo -e "\n[1] Ermittle IP-Adressen der VMs..."
APP_INFO=$(az vm list-ip-addresses --resource-group "$RG" --name "app-vm" --query "[0].virtualMachine.network" -o json)
DB_INFO=$(az vm list-ip-addresses --resource-group "$RG" --name "db-vm" --query "[0].virtualMachine.network" -o json)

APP_PUBLIC_IP=$(echo "$APP_INFO" | jq -r '.publicIpAddresses[0].ipAddress // empty')
APP_PRIVATE_IP=$(echo "$APP_INFO" | jq -r '.privateIpAddresses[0] // empty')

DB_PUBLIC_IP=$(echo "$DB_INFO" | jq -r '.publicIpAddresses[0].ipAddress // empty')
DB_PRIVATE_IP=$(echo "$DB_INFO" | jq -r '.privateIpAddresses[0] // empty')

echo "--- VM Details ---"
echo "App VM: Private IP = ${APP_PRIVATE_IP:-Keine}, Public IP = ${APP_PUBLIC_IP:-Keine}"
echo "DB VM : Private IP = ${DB_PRIVATE_IP:-Keine}, Public IP = ${DB_PUBLIC_IP:-Keine}"
echo "------------------"

# 2. Prüfe APP-VM aus dem Internet
echo -e "\n[2] Test: APP-VM Erreichbarkeit aus dem Internet (Public)"
if [ -n "$APP_PUBLIC_IP" ]; then
  echo "-> Public IP vorhanden: $APP_PUBLIC_IP"
  
  # ICMP Ping Test
  echo -n "-> ICMP Ping zu $APP_PUBLIC_IP: "
  if ping -c 3 -W 2 "$APP_PUBLIC_IP" > /dev/null 2>&1; then
    echo "ERFOLGREICH (ICMP antwortet)"
  else
    echo "KEINE ANTWORT (Erwartet bei Azure Standard-NSG, da ICMP standardmäßig verworfen wird)"
  fi

  # TCP Port 80 Check (HTTP)
  echo -n "-> TCP Port 80 (HTTP) Check: "
  if nc -z -v -w 3 "$APP_PUBLIC_IP" 80 > /dev/null 2>&1; then
    echo "OFFEN (App ist über Port 80 erreichbar!)"
  else
    echo "NICHT ERREICHBAR (Port 80 noch geschlossen oder Webserver/FastAPI noch nicht gestartet)"
  fi
else
  echo "[FEHLER] APP-VM hat keine Public IP!"
fi

# 3. Prüfe DB-VM aus dem Internet
echo -e "\n[3] Test: DB-VM Unerreichbarkeit aus dem Internet (Sicherheitstest)"
if [ -z "$DB_PUBLIC_IP" ]; then
  echo "[BESTANDEN] DB-VM besitzt KEINE Public IP und ist somit direkt vom Internet isoliert."
else
  echo "[WARNUNG] DB-VM besitzt eine Public IP ($DB_PUBLIC_IP)!"
  echo -n "-> Teste Zugriff auf Port 5432 aus dem Internet: "
  if nc -z -v -w 3 "$DB_PUBLIC_IP" 5432 > /dev/null 2>&1; then
    echo "[ALARM] DB-Port 5432 ist aus dem Internet erreichbar!"
  else
    echo "[OK] DB-Port 5432 blockiert."
  fi
fi

# 4. Prüfe interne Verbindung: APP -> DB (Port 5432)
echo -e "\n[4] Test: Interne Verbindung (von APP-VM zu DB-VM auf Port 5432)"
if [ -n "$DB_PRIVATE_IP" ]; then
  echo "Führe Verbindungstest von app-vm zu $DB_PRIVATE_IP:5432 aus..."
  
  RUN_CMD_RESULT=$(az vm run-command invoke \
    --resource-group "$RG" \
    --name "app-vm" \
    --command-id RunShellScript \
    --scripts "nc -z -v -w 3 $DB_PRIVATE_IP 5432" \
    --query "value[0].message" -o tsv 2>&1 || true)

  echo "$RUN_CMD_RESULT"
  if echo "$RUN_CMD_RESULT" | grep -iq "succeeded\|open"; then
    echo "[BESTANDEN] app-vm kann db-vm auf Port 5432 erreichen!"
  else
    echo "[INFO] Verbindung von app-vm zu db-vm konnte (noch) nicht hergestellt werden (evtl. PostgreSQL noch nicht gestartet/gebunden)."
  fi
else
  echo "[FEHLER] DB Private IP nicht gefunden."
fi

echo -e "\n============================================="
echo "   Test abgeschlossen"
echo "============================================="
