#!/usr/bin/env bash
set -euo pipefail

# 0. Parameter laden
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/params.sh"

DOCS_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
mkdir -p "$DOCS_DIR"

OUTPUT_FILE="${DOCS_DIR}/TECHNICAL_WRITEUP.md"

echo "=========================================================="
echo "   Sammle Live-Daten und generiere Dokumentation..."
echo "=========================================================="

# 1. Live-Daten aus Azure abfragen
echo "-> Frage Ressourcendaten aus Azure ab..."
SUB_ID=$(az account show --query id -o tsv)
SUB_NAME=$(az account show --query name -o tsv)

APP_INFO=$(az vm list-ip-addresses -g "$RG" -n "app-vm" --query "[0].virtualMachine.network" -o json 2>/dev/null || echo "{}")
DB_INFO=$(az vm list-ip-addresses -g "$RG" -n "db-vm" --query "[0].virtualMachine.network" -o json 2>/dev/null || echo "{}")

APP_PUBLIC_IP=$(echo "$APP_INFO" | jq -r '.publicIpAddresses[0].ipAddress // empty')
APP_PRIVATE_IP=$(echo "$APP_INFO" | jq -r '.privateIpAddresses[0] // empty')
DB_PRIVATE_IP=$(echo "$DB_INFO" | jq -r '.privateIpAddresses[0] // empty')

# NSG-Regeln
echo "-> Lese NSG-Regeln aus..."
APP_NSG_RULES=$(az network nsg rule list -g "$RG" --nsg-name "app-nsg" --query "[].{Name:name, Priority:priority, Direction:direction, Access:access, Port:destinationPortRanges, Source:sourceAddressPrefixes}" -o table 2>/dev/null || echo "Keine")
DB_NSG_RULES=$(az network nsg rule list -g "$RG" --nsg-name "db-nsg" --query "[].{Name:name, Priority:priority, Direction:direction, Access:access, Port:destinationPortRanges, Source:sourceAddressPrefixes}" -o table 2>/dev/null || echo "Keine")

# Ressourcenliste
echo "-> Erstelle Ressourcen-Inventar..."
RESOURCES_TABLE=$(az resource list -g "$RG" --query "[].{Name:name, Type:type, Location:location, Status:provisioningState}" -o table 2>/dev/null || echo "Keine")

# Monitoring & Alerts
echo "-> Lese Monitoring & Alerts aus..."
ALERTS_TABLE=$(az monitor metrics alert list -g "$RG" --query "[].{Name:name, Enabled:enabled, Severity:severity}" -o table 2>/dev/null || echo "Keine Alerts konfiguriert")
ACTION_GROUPS=$(az monitor action-group list -g "$RG" --query "[].{Name:name, ShortName:groupShortName, Enabled:enabled}" -o table 2>/dev/null || echo "Keine Action Groups")

# API Live-Test
echo "-> Teste Live-API Endpunkte..."
API_DOCS_STATUS="Nicht erreichbar"
API_ENTRIES_RESPONSE="Keine Antwort"
if [ -n "$APP_PUBLIC_IP" ]; then
  HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" -m 5 "http://${APP_PUBLIC_IP}/docs" || echo "000")
  if [ "$HTTP_CODE" == "200" ]; then
    API_DOCS_STATUS="200 OK (Erreichbar)"
  else
    API_DOCS_STATUS="HTTP Status ${HTTP_CODE}"
  fi
  API_ENTRIES_RESPONSE=$(curl -s -m 5 "http://${APP_PUBLIC_IP}/entries" || echo "Keine Antwort")
fi

# Kosten / Budget
echo "-> Frage Budget- und Kosteninformationen ab..."
BUDGET_INFO=$(az rest --method get --uri "/subscriptions/${SUB_ID}/resourceGroups/${RG}/providers/Microsoft.Consumption/budgets?api-version=2021-10-01" --query "value[0].{Name:name, Amount:properties.amount, TimeGrain:properties.timeGrain, Category:properties.category}" -o table 2>/dev/null || echo "Kein Budget hinterlegt")

CURRENT_DATE=$(date "+%d.%m.%Y %H:%M:%S")

# 2. Dokumentations-Markdown generieren
echo "-> Generiere Markdown-Dokumentation in ${OUTPUT_FILE}..."
cat <<EOF > "$OUTPUT_FILE"
# ☁️ Azure 2-Tier Architecture: Technical Writeup & Documentation

*Projekt:* **LearningSteps Cloud Deployment**  
*Resource Group:* \`${RG}\`  
*Region:* \`${REGION}\`  
*Generiert am:* \`${CURRENT_DATE}\`  
*Subscription:* \`${SUB_NAME}\` (\`${SUB_ID}\`)

---

## 1. Architektur-Übersicht (2-Tier Setup)

Die LearningSteps API wurde in einer abgesicherten 2-Tier-Architektur auf Microsoft Azure bereitgestellt. Das Setup trennt die öffentliche Applikationsebene strikt von der internen Datenbankebene.

\`\`\`mermaid
flowchart TD
    subgraph Internet ["🌐 Öffentliches Internet"]
        User["Benutzer / API Client"]
    end

    subgraph AzureCloud ["☁️ Microsoft Azure (germanywestcentral)"]
        subgraph VNet ["Virtual Network: learningsteps-vnet (10.0.0.0/16)"]
            
            subgraph BastionSN ["Subnet: AzureBastionSubnet (10.0.0.0/26)"]
                Bastion["Azure Bastion Host (Standard SKU)"]
            end

            subgraph AppSN ["Subnet: app-sn (10.0.1.0/24)"]
                NSG_App["NSG: app-nsg\n(Erlaubt Port 80 Inbound)"]
                WAF["Host-WAF (Nginx + ModSecurity)\nRate Limiting & Security Headers"]
                AppVM["FastAPI Server (app-vm)\nPublic IP: ${APP_PUBLIC_IP}\nPrivate IP: ${APP_PRIVATE_IP}"]
            end

            subgraph DBSN ["Subnet: db-sn (10.0.2.0/24)"]
                NSG_DB["NSG: db-nsg\n(Erlaubt Port 5432 NUR aus 10.0.1.0/24)"]
                DBVM["PostgreSQL Server (db-vm)\nPrivate IP: ${DB_PRIVATE_IP}\n(Keine Public IP - Streng isoliert)"]
            end
        end

        subgraph MonitoringPlane ["📊 Monitoring & Governance"]
            Law["Log Analytics Workspace\n(law-learningsteps)"]
            Alerts["Azure Monitor Alerts\n(CPU > 80% an seel.dominic@googlemail.com)"]
            Budget["Budget: 15.00 € / Monat\n(Alarm bei 80% & 100%)"]
        end
    end

    User -->|"HTTP Port 80 (Public)"| NSG_App
    NSG_App --> WAF
    WAF -->|"Reverse Proxy"| AppVM
    AppVM -->|"SQL Port 5432 (Internal)"| NSG_DB
    NSG_DB --> DBVM
    Bastion -.->|"Sicherer Admin-SSH Zugriff"| AppVM
    Bastion -.->|"Sicherer Admin-SSH Zugriff"| DBVM
\`\`\`

---

## 2. Live-Status der Infrastruktur

### Netzwerk & Instanzen
| Komponente | VM-Name | Private IP | Public IP | Status |
| :--- | :--- | :--- | :--- | :--- |
| **Tier 1 (App Server)** | \`app-vm\` | \`${APP_PRIVATE_IP}\` | \`${APP_PUBLIC_IP}\` | Betriebsbereit (Port 80) |
| **Tier 2 (Datenbank)** | \`db-vm\` | \`${DB_PRIVATE_IP}\` | *Keine (Isoliert)* | Betriebsbereit (Port 5432) |
| **Management** | \`bastion-host\` | Intern | \`bastion-pip\` | Standard SKU mit Native Tunneling |

### API Endpunkte & Live-Test
- **Swagger UI**: [http://${APP_PUBLIC_IP}/docs](http://${APP_PUBLIC_IP}/docs) -> **${API_DOCS_STATUS}**
- **GET /entries Live-Response**:
\`\`\`json
${API_ENTRIES_RESPONSE}
\`\`\`

---

## 3. Sicherheitsentscheidungen (Least Privilege & Defense-in-Depth)

1. **Strikte Subnetz- und Netzwerkisolierung**:
   - Die Datenbank besitzt **keine öffentliche IP**. Eine direkte Erreichbarkeit aus dem Internet ist auf Netzwerkebene physisch unmöglich.
   - Die Subnetz-NSG \`db-nsg\` limitiert Port 5432 strikt auf das Subnetz der App (\`10.0.1.0/24\`).

2. **Defense-in-Depth (Mehrstufige Abwehr)**:
   - **Ebene 1 (Cloud Firewall)**: Azure NSG auf Subnetzebene blockiert unautorisierten Datenverkehr.
   - **Ebene 2 (Host WAF)**: Nginx mit ModSecurity analysiert eingehende HTTP-Payloads auf SQL-Injections, XSS und schützt durch Rate-Limiting vor DoS-Angriffen.
   - **Ebene 3 (Host Firewall & Brute-Force)**: Lokale \`ufw\` auf den VMs und \`fail2ban\` sperren verdächtige IPs automatisch.
   - **Ebene 4 (System Auditing)**: \`auditd\` überwacht Änderungen an kritischen Konfigurationsdateien (\`/etc/passwd\`, \`/etc/shadow\`, \`/etc/postgresql/\`).

---

## 4. Herausforderungen & Lösungen (Challenges & Troubleshooting)

| Problem / Herausforderung | Ursache | Lösung |
| :--- | :--- | :--- |
| **Port 80 trotz NSG blockiert** | \`az vm create\` erstellte automatisch eine zusätzliche NIC-NSG (\`app-vmNSG\`), die Port 80 abwies. | Entfernen der redundanten NIC-NSGs, sodass ausschließlich die sauberen Subnetz-NSGs greifen. |
| **Interaktiver Dialog blockiert Deployment** | \`iptables-persistent\` forderte bei der Installation Tastatureingaben im Hintergrund an. | Ergänzen von \`DEBIAN_FRONTEND=noninteractive\` und \`dpkg --configure -a\`. |
| **Legacy Budget API Fehler (400)** | Veralteter Preview-Befehl \`az consumption budget create\` erforderte alte Filtersyntax. | Umstellung auf die moderne ARM Consumption REST-API (\`2021-10-01\`) mit integrierten E-Mail-Schwellenwerten. |

---

## 5. Key Learnings (Erkenntnisse über Azure Networking)

1. **Subnet-NSG vs. NIC-NSG**:
   - Datenverkehr durchläuft bei eingehenden Verbindungen zuerst die Subnet-NSG und danach die NIC-NSG. Für eine saubere Verwaltung sollten NSGs auf Subnetzebene gebündelt werden, um Inkonsistenzen zu vermeiden.
2. **Azure Bastion Funktionsweise**:
   - Ermöglicht verschlüsselte Administrationsverbindungen zu privaten VMs, ohne dass diese eine Public IP oder exponierte SSH-Ports benötigen.
3. **Kostenkontrolle in der Cloud**:
   - Nicht alle Cloud-Kosten skalieren mit der Nutzung. Pauschal abgerechnete Basis-Komponenten (wie Bastion oder Gateways) erfordern proaktive Budgets und Alerting.

---

## 6. Ressourcen-Inventar

\`\`\`text
${RESOURCES_TABLE}
\`\`\`

### Konfigurierte NSG-Regeln
**app-nsg:**
\`\`\`text
${APP_NSG_RULES}
\`\`\`

**db-nsg:**
\`\`\`text
${DB_NSG_RULES}
\`\`\`

### Monitoring & Budget Status
**Aktive Metrik-Alerts:**
\`\`\`text
${ALERTS_TABLE}
\`\`\`

**Kosten-Budget:**
\`\`\`text
${BUDGET_INFO}
\`\`\`
EOF

echo "=========================================================="
echo "   Dokumentation erfolgreich erstellt unter:"
echo "   ${OUTPUT_FILE}"
echo "=========================================================="
