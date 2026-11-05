# 📋 LearningSteps Cloud Deployment: Executive Summary

*Projekt:* **LearningSteps Azure 2-Tier Architecture**  
*Autor:* **Dominic Sebastian Seel**  
*Resource Group:* \`learningsteps-lab-rg\`  
*Region:* \`germanywestcentral\` (Frankfurt)  
*Status:* ✅ **Erfolgreich abgeschlossen & verifiziert**

---

## 1. Projektübersicht & Zielsetzung

Ziel des Projekts war die Überführung der lokalen FastAPI-Applikation **LearningSteps** in eine sichere, produktionsreife 2-Tier-Architektur auf Microsoft Azure unter Berücksichtigung moderner Cloud-Networking-, Security- und DevOps-Prinzipien.

### Kernanforderungen & Architektur

- **Tier 1 (Application Tier)**: Öffentlich erreichbarer FastAPI-Server (`app-vm`) auf Port 80 / 443 mit vorgeschalteter Host-basierter Web Application Firewall (WAF) und Reverse Proxy.
- **Tier 2 (Database Tier)**: Streng isolierter PostgreSQL-Datenbankserver (`db-vm`) im privaten Subnetz ohne Public IP. Erreichbar ausschließlich aus dem Applikations-Subnetz über Port 5432.
- **Management & Security**: Sicherer Administrationszugriff über Azure Bastion (Standard SKU mit Native Tunneling) ohne öffentlich exponierte SSH-Ports.
- **Monitoring & Kostenkontrolle**: 2-Ebenen-Monitoring (Azure Monitor Alerts + Log Analytics Workspace) sowie automatisierte Budgetüberwachung (15,00 € monatlich mit E-Mail-Warnungen).

---

## 2. Erfüllte Erfolgskriterien (Success Criteria Audit)

| Kriterium | Vorgabe (project.md) | Umgesetzte Lösung | Status |
| :--- | :--- | :--- | :---: |
| **Öffentlicher Zugriff** | API muss über Public IP oder Domain erreichbar sein. | Public IP `{IP}}` eingerichtet; Swagger UI unter `http://{IP}}/docs` erreichbar. | ✅ |
| **Datenbank-Isolation** | DB darf keinesfalls direkt aus dem Internet erreichbar sein. | `db-vm` besitzt keine Public IP; Internet-Probes schlagen fehl; Zugriff von `app-vm` (Port 5432) funktioniert. | ✅ |
| **CRUD-Funktionalität** | Alle Endpunkte (Erstellen, Lesen, Aktualisieren, Löschen) müssen funktionieren. | Offizielle Testsuite `test_api.py` und manuelle API-Tests gegen Public IP ausgeführt: **100 % Erfolgsquote**. | ✅ |
| **Datenpersistenz** | Daten müssen Neustarts und Redeployments überdauern. | PostgreSQL läuft auf dedizierter VM mit Managed OS-Disk (`entries`-Tabelle mit GIN-Index). | ✅ |
| **Least Privilege NSGs** | Netzwerksicherheitsgruppen müssen minimal permissiv sein. | `app-nsg` öffnet nur Port 80; `db-nsg` beschränkt Port 5432 strikt auf das Subnetz `10.0.1.0/24`. | ✅ |
| **Dokumentation** | Technisches Writeup mit Architekturdiagramm, Security Decisions und Learnings. | Vollständig dokumentiert in [documentation/TECHNICAL_WRITEUP.md](TECHNICAL_WRITEUP.md). | ✅ |

---

## 3. Sicherheits- & Härtungskonzept (Defense-in-Depth)

1. **Cloud-Ebene (Azure Network Security Groups)**:
   - Verknüpfung der NSGs direkt auf Subnetzebene (`app-sn`, `db-sn`).
   - Keine störenden oder inkonsistenten NIC-Level-Firewalls.
2. **Applikationsebene (Host-WAF & Reverse Proxy)**:
   - Nginx mit **ModSecurity v3 Engine** (OWASP Core Rule Set) zur Erkennung und Abwehr von SQL-Injections, XSS und Remote Code Execution.
   - HTTP Security Headers (`X-Frame-Options`, `X-Content-Type-Options`, `X-XSS-Protection`, `Referrer-Policy`).
   - Rate-Limiting (15 Requests/s, Burst bis 30) zum Schutz vor DoS- und Brute-Force-Angriffen.
3. **Betriebssystem- & Host-Ebene (UFW & Fail2ban)**:
   - Lokale `ufw`-Firewall auf beiden VMs mit Default Deny Incoming.
   - `fail2ban` sperrt IP-Adressen nach 3 Fehlversuchen für 1 Stunde (SSH- und Web-Jails).
   - `auditd` überwacht und protokolliert unbefugte Änderungen an kritischen Systemdateien (`/etc/passwd`, `/etc/shadow`, `/etc/postgresql/`).
   - Kernel-Sysctl-Schutz vor SYN-Flooding und ICMP-Redirect-Manipulationen.

---

## 4. Kosten- & Betriebsmanagement

Zur Kostenoptimierung und Vermeidung unnötiger Cloud-Gebühren wurden dedizierte Skripte für den Lebenszyklus bereitgestellt:

- **Leerlauf / Feierabend (`pause_vms.sh`)**:
  - **Rechenkosten**: VMs werden deallokiert (`az vm deallocate`), Compute-Kosten fallen auf **0,00 €**.
  - **Bastion-Kosten**: Der Bastion Host (~140 €/Monat bzw. ~0,19 €/Std.) wird während der Pause gelöscht. Subnetz und statische Public IP bleiben erhalten.
  - **Storage-Kosten**: OS-Disks werden temporär auf die günstigste Storage-Klasse (`Standard_LRS`) herabgestuft (über 60 % Ersparnis).
- **Arbeitsmodus (`start_vms.sh`)**:
  - Reaktiviert Hochleistungsdisks (`Premium_LRS`).
  - Fährt die VMs hoch (statische Public IP `{IP}}` bleibt erhalten).
  - Stellt den Bastion Host bei Bedarf im Hintergrund (`--no-wait`) wieder her.

---

## 5. Skript-Übersicht (`documentation/scripts/`)

| Skript | Beschreibung |
| :--- | :--- |
| **[init.sh](scripts/init.sh)** | Führt den gesamten Aufbau von 0 bis 100 in korrekter Reihenfolge aus. |
| **[create_az_environment.sh](scripts/create_az_environment.sh)** | Erstellt Resource Group, VNet, Subnetze, Bastion, VMs und NSGs. |
| **[deploy.sh](scripts/deploy.sh)** | Rüstet PostgreSQL & FastAPI ein, richtet Portweiterleitung und 15-Min-Healthcheck ein. |
| **[check_connectivity.sh](scripts/check_connectivity.sh)** | Führt automatisierte Verbindungstests (Public, Private, Port 5432) durch. |
| **[improvments.sh](scripts/improvments.sh)** | Richtet Nginx-WAF, 2 Ebenen Monitoring und das 15 € Budget ein. |
| **[hardening.sh](scripts/hardening.sh)** | Aktiviert UFW, Fail2ban, Auditd, SSH- und Kernel-Härtung. |
| **[generate_documentation.sh](scripts/generate_documentation.sh)** | Fragt Azure-Livedaten ab und aktualisiert das technische Writeup. |
| **[pause_vms.sh](scripts/pause_vms.sh)** | Pausiert alle Ressourcen und senkt Leerlaufkosten auf ein absolutes Minimum. |
| **[start_vms.sh](scripts/start_vms.sh)** | Fährt die Umgebung wieder hoch und stellt Performance & Bastion her. |
| **[cleanup.sh](scripts/cleanup.sh)** | Löscht die gesamte Resource Group rückstandslos aus Azure. |
| **[params.sh](scripts/params.sh)** | Zentrale Konfigurationsparameter (`RG`, `REGION`, `VNET`). |
