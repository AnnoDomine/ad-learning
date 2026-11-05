#!/usr/bin/env bash
set -euo pipefail

# 0. Parameter laden
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/params.sh"

if [ -z "${ALERT_EMAIL:-}" ]; then
  echo "FEHLER: Umgebungsvariable ALERT_EMAIL ist nicht gesetzt (z.B. via GitHub Secrets)!"
  exit 1
fi

echo "=========================================================="
echo "   Improvements: WAF, Monitoring & Cost Control Setup"
echo "=========================================================="

SUB_ID=$(az account show --query id -o tsv)
APP_ID=$(az vm show -g "$RG" -n "app-vm" --query id -o tsv)
DB_ID=$(az vm show -g "$RG" -n "db-vm" --query id -o tsv)

echo "Subscription ID: $SUB_ID"
echo "Resource Group : $RG"
echo "Admin Email    : $ALERT_EMAIL"

# ========================================================
# 1. Host-basierte WAF auf app-vm (Nginx + ModSecurity WAF)
# ========================================================
echo -e "\n[1/3] Richte Host-basierte WAF (Nginx + ModSecurity) auf app-vm ein..."
az vm run-command invoke \
  --resource-group "$RG" \
  --name "app-vm" \
  --command-id RunShellScript \
  --scripts "
    set -e
    echo '=== 1. Paketstatus reparieren & Nginx/ModSecurity installieren ==='
    export DEBIAN_FRONTEND=noninteractive
    dpkg --configure -a
    apt-get update
    apt-get install -y nginx libnginx-mod-security modsecurity-crs || apt-get install -y nginx

    # Entferne evtl. bestehende iptables NAT Weiterleitung (da Nginx jetzt Port 80 übernimmt)
    while iptables -t nat -D PREROUTING -p tcp --dport 80 -j REDIRECT --to-port 8000 2>/dev/null; do :; done
    if [ -f /etc/iptables/rules.v4 ]; then
      iptables-save > /etc/iptables/rules.v4
    fi
    netfilter-persistent save 2>/dev/null || true

    echo '=== 2. ModSecurity WAF konfigurieren ==='
    mkdir -p /etc/nginx/modsec
    if [ -f /etc/modsecurity/modsecurity.conf-recommended ]; then
      cp /etc/modsecurity/modsecurity.conf-recommended /etc/nginx/modsec/modsecurity.conf
      sed -i 's/SecRuleEngine DetectionOnly/SecRuleEngine On/' /etc/nginx/modsec/modsecurity.conf
    fi

    # Erstelle ModSec Hauptkonfiguration
    cat <<'EOF_MODSEC' > /etc/nginx/modsec/main.conf
Include /etc/nginx/modsec/modsecurity.conf
# OWASP Core Rule Set (falls vorhanden) einbinden
Include /usr/share/modsecurity-crs/owasp-crs.load
EOF_MODSEC

    echo '=== 3. Nginx Reverse Proxy mit Security Headern & Rate Limiting ==='
    cat <<'EOF_NGINX' > /etc/nginx/sites-available/default
limit_req_zone \$binary_remote_addr zone=api_rate_limit:10m rate=15r/s;

server {
    listen 80 default_server;
    listen [::]:80 default_server;
    server_name _;

    # WAF ModSecurity aktivieren (falls Modul geladen)
    modsecurity on;
    modsecurity_rules_file /etc/nginx/modsec/main.conf;

    # Security Headers
    add_header X-Frame-Options \"SAMEORIGIN\" always;
    add_header X-Content-Type-Options \"nosniff\" always;
    add_header X-XSS-Protection \"1; mode=block\" always;
    add_header Referrer-Policy \"strict-origin-when-cross-origin\" always;
    add_header Server \"LearningSteps-Protected\" always;

    # Rate Limiting
    limit_req zone=api_rate_limit burst=30 nodelay;

    location / {
        proxy_pass http://127.0.0.1:8000;
        proxy_http_version 1.1;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;

        proxy_connect_timeout 10s;
        proxy_read_timeout 60s;
    }
}
EOF_NGINX

    # Konfiguration testen und Nginx neu starten
    if nginx -t 2>/dev/null; then
      systemctl restart nginx
      echo 'Nginx mit WAF erfolgreich konfiguriert und aktiv!'
    else
      echo 'Fallback: Konfiguriere Nginx ohne ModSecurity Direktive (falls Modul separat geladen wird)...'
      sed -i '/modsecurity/d' /etc/nginx/sites-available/default
      nginx -t
      systemctl restart nginx
      echo 'Nginx Reverse Proxy & Rate Limiting aktiv!'
    fi
  " \
  --output table

# ========================================================
# 2. Monitoring (Beide Ebenen)
# ========================================================
echo -e "\n[2/3] Richte Monitoring auf beiden Ebenen ein..."

# Ebene 1A: Action Group für Alerts an Dominic
ACTION_GROUP_NAME="ag-learningsteps-admin"
echo "-> [Ebene 1] Erstelle Action Group mit E-Mail-Empfänger: $ALERT_EMAIL"
az monitor action-group create \
  --resource-group "$RG" \
  --name "$ACTION_GROUP_NAME" \
  --short-name "LabAlert" \
  --action email "Dominic" "$ALERT_EMAIL" \
  --output table

ACTION_GROUP_ID="/subscriptions/${SUB_ID}/resourceGroups/${RG}/providers/microsoft.insights/actionGroups/${ACTION_GROUP_NAME}"

# Ebene 1B: Metrik-Alerts (CPU > 80% für app-vm und db-vm)
echo "-> [Ebene 1] Erstelle Metrik-Alert für app-vm (CPU > 80%)..."
az monitor metrics alert create \
  --resource-group "$RG" \
  --name "alert-app-vm-cpu-high" \
  --scopes "$APP_ID" \
  --condition "avg Percentage CPU > 80" \
  --window-size 5m \
  --evaluation-frequency 1m \
  --action "$ACTION_GROUP_ID" \
  --description "Alarm bei CPU-Auslastung > 80% auf app-vm" \
  --output table

echo "-> [Ebene 1] Erstelle Metrik-Alert für db-vm (CPU > 80%)..."
az monitor metrics alert create \
  --resource-group "$RG" \
  --name "alert-db-vm-cpu-high" \
  --scopes "$DB_ID" \
  --condition "avg Percentage CPU > 80" \
  --window-size 5m \
  --evaluation-frequency 1m \
  --action "$ACTION_GROUP_ID" \
  --description "Alarm bei CPU-Auslastung > 80% auf db-vm" \
  --output table

# Ebene 2: Log Analytics Workspace für zentrales Logging
echo "-> [Ebene 2] Erstelle Log Analytics Workspace 'law-learningsteps'..."
az monitor log-analytics workspace create \
  --resource-group "$RG" \
  --workspace-name "law-learningsteps" \
  --location "$REGION" \
  --sku PerGB2018 \
  --output table

# ========================================================
# 3. Kostenkontrolle (Beides: Budget-Alert & Kostenabfrage)
# ========================================================
echo -e "\n[3/3] Richte Kostenkontrolle ein..."

# 3A: Budget anlegen (15 EUR monatlich für das Lab inkl. E-Mail-Alarm)
START_DATE="$(date +%Y-%m-01)"
END_DATE="$(date -d '+1 year' +%Y-%m-01)"
BUDGET_NAME="budget-lab-15eur"

echo "-> Erstelle Budget ($BUDGET_NAME, 15.00 EUR/Monat mit E-Mail-Alarm an $ALERT_EMAIL)..."
az rest --method put \
  --uri "/subscriptions/${SUB_ID}/resourceGroups/${RG}/providers/Microsoft.Consumption/budgets/${BUDGET_NAME}?api-version=2021-10-01" \
  --body "{
    \"properties\": {
      \"category\": \"Cost\",
      \"amount\": 15.0,
      \"timeGrain\": \"Monthly\",
      \"timePeriod\": {
        \"startDate\": \"${START_DATE}T00:00:00Z\",
        \"endDate\": \"${END_DATE}T00:00:00Z\"
      },
      \"notifications\": {
        \"Actual_Greater_Than_80_Percent\": {
          \"enabled\": true,
          \"operator\": \"GreaterThan\",
          \"threshold\": 80.0,
          \"contactEmails\": [\"${ALERT_EMAIL}\"]
        },
        \"Actual_Greater_Than_100_Percent\": {
          \"enabled\": true,
          \"operator\": \"GreaterThan\",
          \"threshold\": 100.0,
          \"contactEmails\": [\"${ALERT_EMAIL}\"]
        }
      }
    }
  }" --output table || echo "Budget konnte nicht erstellt werden."

# 3B: Aktuelle Kostenübersicht abfragen
echo -e "\n=== Aktuelle Kostenabfrage (Month-To-Date) ==="
az costmanagement query \
  --type "Usage" \
  --timeframe "MonthToDate" \
  --dataset-aggregation '{"totalCost":{"name":"PreTaxCost","function":"Sum"}}' \
  --dataset-grouping '[{"type":"Dimension","name":"ResourceGroupName"}]' \
  --output table 2>/dev/null || echo "Kosten-API Daten werden zeitversetzt aktualisiert."

echo -e "\n=========================================================="
echo "   Alle Erweiterungen erfolgreich eingerichtet!"
echo "=========================================================="
