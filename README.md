# LearningSteps: Cloud Architecture & DevOps Journey

Dieses Repository dokumentiert den gesamten Entwicklungsweg der **LearningSteps** REST-API – von der klassischen, VM-basierten 2-Tier-Architektur in Microsoft Azure bis hin zu einer modernen, containerisierten und Cloud-Native-Orchestrierung.

---

## 📂 Repository-Struktur

```text
.
├── 01_learningsteps_origin.md       # Aufgabenstellung & Spezifikation: Projekt 1 (Origin)
├── 02_learningsteps_evolution.md    # Aufgabenstellung & Spezifikation: Projekt 2 (Evolution)
├── AGENTS.md                        # Leitfaden für KI-Agenten (Copilot- & Mentoren-Modus)
├── documentation/                   # Artefakte & Automatisierung aus Projekt 1
│   ├── scripts/                     # Azure CLI Provisionierungs-, Deployment- & Wartungsskripte
│   ├── ORIGIN_SUMMARY.md                   # Executive Summary von Projekt 1
│   └── TECHNICAL_WRITEUP.md         # Ausführlicher technischer Bericht zu Projekt 1
└── learningsteps/                   # Quellcode der FastAPI-Anwendung (Übungs-Repository)
    ├── api/                         # FastAPI Endpunkte, Models, Repositories, Services
    ├── database_setup.sql           # Schema für PostgreSQL
    ├── requirements.txt             # Python Abhängigkeiten
    ├── start.sh                     # Lokales Startskript
    └── test_api.py                  # API Integrationstests
```

---

## 🚀 Die zwei Meilensteine

### 1. [Projekt 1: LearningSteps Origin](01_learningsteps_origin.md) (Abgeschlossen)
* **Ziel**: Errichtung einer sicheren 2-Tier-Architektur auf Azure Virtual Machines.
* **Tier 1 (Public)**: FastAPI Applikationsserver mit UFW, Nginx-Reverse Proxy und ModSecurity WAF.
* **Tier 2 (Private)**: Isolierter PostgreSQL-Server ohne Public IP, erreichbar nur via privatem VNet (`10.0.0.0/16`).
* **Automatisierung**: Skriptgesteuerte Erstellung und Verwaltung via Azure CLI im Verzeichnis [`documentation/scripts/`](documentation/scripts/).

### 2. [Projekt 2: LearningSteps Evolution](02_learningsteps_evolution.md) (Aktiver Fokus 🔥)
* **Ziel**: Transformation von manueller/skriptbasierter VM-Infrastruktur hin zu einem vollständig automatisierten, Cloud-Native DevOps-Lebenszyklus.
* **Kernbereiche**:
  1. **Containerisierung**: Leichtgewichtiges, produktionsreifes Dockerfile für die FastAPI-App.
  2. **Infrastructure as Code (IaC)**: Deklarative Bereitstellung aller Azure-Ressourcen (VNet, Subnetze, AKS, Azure Database for PostgreSQL Flexible Server, Azure Key Vault) via **Terraform**.
  3. **DevSecOps & CI/CD**: GitHub Actions Pipelines mit integrierten Sicherheitsscans (Secret Scanning, Trivy Container Vulnerability Scan, Checkov/tfsec IaC-Scan).
  4. **Container-Orchestrierung**: Kubernetes-Manifeste (Deployments, Services, ConfigMaps, Secrets, HPA) auf **Azure Kubernetes Service (AKS)**.
  5. *(Optional)* **Observability**: Prometheus-Metriken in FastAPI und Visualisierung via Grafana-Dashboards.

---

## 🛠️ Schnellstart & Lokale Entwicklung

Die Anwendung im Unterordner [`learningsteps/`](learningsteps/) kann lokal gestartet und getestet werden:

1. **Python Virtual Environment anlegen**:
   ```bash
   cd learningsteps
   python3 -m venv venv
   source venv/bin/activate
   pip install -r api/requirements.txt
   ```

2. **Umgebungsvariablen konfigurieren (`.env`)**:
   Vorlage `.env-sample` nach `.env` kopieren und eigene Secrets definieren:
   ```bash
   cp .env-sample .env
   ```
   ```env
   POSTGRES_USER=<YOUR_POSTGRES_USER>
   POSTGRES_PASSWORD=<YOUR_POSTGRES_PASSWORD>
   POSTGRES_DB=learning_journal
   DATABASE_URL=postgresql://<YOUR_POSTGRES_USER>:<YOUR_POSTGRES_PASSWORD>@localhost:5432/learning_journal
   ```

3. **API starten**:
   ```bash
   ./start.sh
   # oder: uvicorn api.main:app --reload --port 8000
   ```

4. **Tests ausführen**:
   ```bash
   python test_api.py
   ```

---

## 📜 Skripte & Legacy-Automatisierung (`documentation/scripts/`)

Für Projekt 1 stehen modulare Shell-Skripte zur Verfügung:
* `init.sh`: Kompletter End-to-End-Setup (Infrastruktur, Deployment, Härtung, Doku).
* `deploy.sh`: Provisioniert PostgreSQL und verankert die FastAPI-App direkt aus diesem Repository (`learningsteps`-Unterordner).
* `pause_vms.sh` / `start_vms.sh`: Kostensenkungs- und Reaktivierungsroutinen.
* `params.sh`: Zentrale Konfiguration (Resource Group, Region, Repo-URL, Branch).
