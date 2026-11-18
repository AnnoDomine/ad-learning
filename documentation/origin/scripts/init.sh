#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "=========================================================="
echo "   🚀 LearningSteps Cloud Deployment: Full Initialization"
echo "=========================================================="
echo "Startzeit: $(date '+%d.%m.%Y %H:%M:%S')"
echo "Folgende Schritte werden in Reihenfolge ausgeführt:"
echo "  1. create_az_environment.sh  (Infrastruktur, VNet, Bastion, VMs, NSGs)"
echo "  2. deploy.sh                 (PostgreSQL Setup, FastAPI Service, Healthcheck)"
echo "  3. check_connectivity.sh     (Netzwerk- und Konnektivitätsprüfung)"
echo "  4. improvments.sh            (Host-WAF, 2-Ebenen-Monitoring, Budget)"
echo "  5. hardening.sh              (UFW Firewall, Fail2ban, Auditd, OS-Härtung)"
echo "  6. generate_documentation.sh (Live-Dokumentation in ./documentation/)"
echo "=========================================================="

echo -e "\n>>> [1/6] Starte Infrastruktur-Erstellung..."
"${SCRIPT_DIR}/create_az_environment.sh"

echo -e "\n>>> [2/6] Starte Anwendungs- und Datenbank-Deployment..."
"${SCRIPT_DIR}/deploy.sh"

echo -e "\n>>> [3/6] Starte Konnektivitätsprüfung..."
"${SCRIPT_DIR}/check_connectivity.sh"

echo -e "\n>>> [4/6] Starte WAF, Monitoring & Budget-Setup..."
"${SCRIPT_DIR}/improvments.sh"

echo -e "\n>>> [5/6] Starte System- und Netzwerkhärtung..."
"${SCRIPT_DIR}/hardening.sh"

echo -e "\n>>> [6/6] Generiere Projektdokumentation..."
"${SCRIPT_DIR}/generate_documentation.sh"

echo -e "\n=========================================================="
echo "   🎉 Vollständige Initialisierung erfolgreich beendet!"
echo "   Dokumentation: ./documentation/TECHNICAL_WRITEUP.md"
echo "   Endzeit: $(date '+%d.%m.%Y %H:%M:%S')"
echo "=========================================================="
