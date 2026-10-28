#!/usr/bin/env bash
set -euo pipefail

# 0. Parameter laden
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/params.sh"

echo "============================================="
echo "   Deploy LearningSteps to Azure VMs"
echo "============================================="

# 1. IP-Adressen ermitteln
echo "[1/4] Ermittle IP-Adressen der VMs..."
DB_PRIVATE_IP=$(az vm list-ip-addresses -g "$RG" -n "db-vm" --query "[0].virtualMachine.network.privateIpAddresses[0]" -o tsv)
APP_PUBLIC_IP=$(az vm list-ip-addresses -g "$RG" -n "app-vm" --query "[0].virtualMachine.network.publicIpAddresses[0].ipAddress" -o tsv)

if [ -z "$DB_PRIVATE_IP" ]; then
  echo "FEHLER: Konnte private IP der db-vm nicht ermitteln. Läuft die VM bereits?"
  exit 1
fi

echo "-> DB Private IP : $DB_PRIVATE_IP"
echo "-> App Public IP : ${APP_PUBLIC_IP:-Keine}"

# 2. Datenbank konfigurieren auf db-vm
echo -e "\n[2/4] Konfiguriere PostgreSQL auf db-vm..."
az vm run-command invoke \
  --resource-group "$RG" \
  --name "db-vm" \
  --command-id RunShellScript \
  --scripts "
    set -e
    echo '=== Starte PostgreSQL Setup ==='
    apt-get update && apt-get install -y postgresql postgresql-contrib

    systemctl start postgresql
    systemctl enable postgresql

    # PostgreSQL Benutzer und Datenbank anlegen falls noch nicht vorhanden
    sudo -u postgres psql -c \"ALTER USER postgres WITH PASSWORD 'postgres';\"
    sudo -u postgres psql -tc \"SELECT 1 FROM pg_database WHERE datname = 'learning_journal'\" | grep -q 1 || \
      sudo -u postgres psql -c \"CREATE DATABASE learning_journal;\"

    # Tabellen initialisieren (database_setup.sql)
    sudo -u postgres psql -d learning_journal -c \"
      CREATE TABLE IF NOT EXISTS entries (
          id VARCHAR PRIMARY KEY,
          data JSONB NOT NULL,
          created_at TIMESTAMP WITH TIME ZONE NOT NULL,
          updated_at TIMESTAMP WITH TIME ZONE NOT NULL
      );
      CREATE INDEX IF NOT EXISTS idx_entries_created_at ON entries(created_at);
      CREATE INDEX IF NOT EXISTS idx_entries_data_gin ON entries USING GIN (data);
    \"

    # Konfiguration anpassen für VNet-Zugriff
    PG_CONF=\$(ls /etc/postgresql/*/main/postgresql.conf | head -n 1)
    PG_HBA=\$(ls /etc/postgresql/*/main/pg_hba.conf | head -n 1)

    sed -i \"s/#listen_addresses = 'localhost'/listen_addresses = '*'/\" \"\$PG_CONF\"
    sed -i \"s/listen_addresses = 'localhost'/listen_addresses = '*'/\" \"\$PG_CONF\"

    # Subnetz-Zugriff in pg_hba.conf erlauben
    if ! grep -q '10.0.0.0/16' \"\$PG_HBA\"; then
      echo 'host    all             all             10.0.0.0/16            md5' >> \"\$PG_HBA\"
    fi

    systemctl restart postgresql
    echo '=== PostgreSQL erfolgreich eingerichtet und neu gestartet ==='
  " \
  --output table

# 3. Application konfigurieren auf app-vm
echo -e "\n[3/4] Deploye FastAPI Applikation auf app-vm..."
az vm run-command invoke \
  --resource-group "$RG" \
  --name "app-vm" \
  --command-id RunShellScript \
  --scripts "
    set -e
    echo '=== 1. Pakete & Abhängigkeiten vorbereiten ==='
    apt-get update
    DEBIAN_FRONTEND=noninteractive apt-get install -y python3 python3-pip python3-venv git curl iptables iptables-persistent || true

    echo '=== 2. Repository klonen / aktualisieren ==='
    if [ ! -d '/opt/learningsteps' ]; then
      git clone -b reference https://github.com/CyberstepsDE/learningsteps.git /opt/learningsteps
    else
      cd /opt/learningsteps && git fetch && git checkout reference && git pull origin reference || true
    fi

    cd /opt/learningsteps

    echo '=== 3. Python Virtualenv & Dependencies ==='
    if [ ! -d 'venv' ]; then
      python3 -m venv venv
    fi
    ./venv/bin/pip install --upgrade pip
    ./venv/bin/pip install -r api/requirements.txt

    echo '=== 4. .env Datei erzeugen ==='
    cat <<EOF > /opt/learningsteps/.env
POSTGRES_USER=postgres
POSTGRES_PASSWORD=postgres
POSTGRES_DB=learning_journal
DATABASE_URL=postgresql://postgres:postgres@${DB_PRIVATE_IP}:5432/learning_journal
EOF

    echo '=== 5. Portweiterleitung (80 -> 8000) einrichten ==='
    # Leitet externen Traffic von Port 80 transparent auf Port 8000 weiter
    if ! iptables -t nat -C PREROUTING -p tcp --dport 80 -j REDIRECT --to-port 8000 2>/dev/null; then
      iptables -t nat -A PREROUTING -p tcp --dport 80 -j REDIRECT --to-port 8000
    fi

    echo '=== 6. Systemd Service für FastAPI erstellen ==='
    cat <<EOF > /etc/systemd/system/learningsteps.service
[Unit]
Description=LearningSteps FastAPI Service
After=network.target

[Service]
User=root
WorkingDirectory=/opt/learningsteps/api
EnvironmentFile=/opt/learningsteps/.env
ExecStart=/opt/learningsteps/venv/bin/uvicorn main:app --host 0.0.0.0 --port 8000
Restart=always
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF

    systemctl daemon-reload
    systemctl enable learningsteps.service
    systemctl restart learningsteps.service

    echo '=== 7. Healthcheck Script & Cron einrichten (alle 15 Min Port 8000) ==='
    # Healthcheck Skript anlegen
    cat << 'EOF_HC' > /usr/local/bin/check_app_health.sh
#!/bin/bash
TARGET_URL=\"http://127.0.0.1:8000/docs\"
LOG_FILE=\"/var/log/learningsteps_health.log\"

# Prüfe Port 8000 mit curl
if ! curl -s -f \"\$TARGET_URL\" > /dev/null 2>&1; then
  echo \"\$(date '+%Y-%m-%d %H:%M:%S') - [FEHLER] Port 8000 nicht erreichbar! Starte learningsteps.service neu...\" >> \"\$LOG_FILE\"
  systemctl restart learningsteps.service
else
  echo \"\$(date '+%Y-%m-%d %H:%M:%S') - [OK] Port 8000 antwortet gesund.\" >> \"\$LOG_FILE\"
fi
EOF_HC

    chmod +x /usr/local/bin/check_app_health.sh

    # Cronjob alle 15 Minuten registrieren falls noch nicht vorhanden
    CRON_FILE=\"/etc/cron.d/learningsteps_health\"
    echo \"*/15 * * * * root /usr/local/bin/check_app_health.sh\" > \"\$CRON_FILE\"
    chmod 0644 \"\$CRON_FILE\"

    echo '=== Führe sofortigen Healthcheck aus ==='
    sleep 3
    /usr/local/bin/check_app_health.sh
    cat /var/log/learningsteps_health.log
  " \
  --output table

# 4. Abschluss & Test-URL
echo -e "\n============================================="
echo "   Deployment erfolgreich abgeschlossen!"
echo "============================================="
if [ -n "$APP_PUBLIC_IP" ]; then
  echo "Swagger UI erreichbar unter : http://${APP_PUBLIC_IP}/docs"
  echo "API Root erreichbar unter   : http://${APP_PUBLIC_IP}/"
fi
