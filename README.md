# LearningSteps: Cloud Architecture & DevOps Journey

Dieses Repository dokumentiert den gesamten Entwicklungsweg der **LearningSteps** REST-API – von der klassischen, VM-basierten 2-Tier-Architektur in Microsoft Azure (**Teil 1: Origin**) bis hin zu einer containerisierten, automatisierten Cloud-Native-Orchestrierung auf AKS (**Teil 2: Evolution**).

---

## 📂 Repository-Struktur

```text
.
├── 01_learningsteps_origin.md       # Aufgabenstellung & Spezifikation: Projekt 1 (Origin)
├── 02_learningsteps_evolution.md    # Aufgabenstellung & Spezifikation: Projekt 2 (Evolution)
├── AGENTS.md                        # Leitfaden für KI-Agenten (Copilot- & Mentoren-Modus)
├── Dockerfile                       # Gehärtetes Multi-Step-Container-Image (Python 3.13-slim)
├── generate_trivy_logs.sh           # Lokales Hilfsskript für Trivy-Security-Logs
├── .github/workflows/               # GitHub Actions CI/CD & DevSecOps-Pipelines
│   ├── lint.yml                     # Ruff (Lint/Format) & Pytest Smoke-Test
│   ├── trivy.yml                    # Trivy Security Scans (IaC, K8s, Image, Secrets -> SARIF)
│   ├── codeql.yml                   # GitHub CodeQL SAST-Analyse für Python
│   ├── tag.yml                      # Manuelles Release-Tagging (v*.*.*)
│   ├── deploy.yml                   # OIDC Azure Login, Terraform, ACR Push, AKS Deploy & Health-Check
│   └── destroy.yml                  # Manueller Infrastructure-Cleanup (mit Confirm-Guardrail)
├── infra-terraform/                 # Infrastructure as Code (VNet, AKS, PostgreSQL, Key Vault, ACR)
├── k8s-manifests/                   # Kubernetes-Manifeste (Deployment, LoadBalancer, ConfigMap, CSI-Secret, HPA)
├── documentation/                   # Projektdokumentation, nach Meilensteinen getrennt
│   ├── README.md                    # Zentrale Doku-Übersicht (Origin & Evolution)
│   ├── origin/                      # Teil 1: Azure-CLI-Skripte, Executive Summary & Technical Writeup
│   └── evolution/                   # Teil 2: Summary, Verlaufsjournal, Roadmap, Notizen, Screenshots & Skripte
└── learningsteps/                   # Quellcode der FastAPI-Anwendung & Tests
    ├── api/                         # FastAPI Endpunkte, Models, Repositories, Services
    ├── tests/                       # Pytest Smoke-Tests
    ├── database_setup.sql           # Schema für PostgreSQL
    ├── ruff.toml                    # Ruff Linter-Konfiguration
    ├── start.sh                     # Lokales Startskript
    └── test_api.py                  # Manuelles API-Integrationstest-Skript
```

---

## 🚀 Die zwei Meilensteine

### 1. [Projekt 1: LearningSteps Origin](01_learningsteps_origin.md) (Abgeschlossen ✅)
* **Ziel**: Errichtung einer sicheren 2-Tier-Architektur auf Azure Virtual Machines.
* **Tier 1 (Public)**: FastAPI Applikationsserver mit UFW, Nginx-Reverse Proxy und ModSecurity WAF.
* **Tier 2 (Private)**: Isolierter PostgreSQL-Server ohne Public IP, erreichbar nur via privatem VNet (`10.0.0.0/16`).
* **Dokumentation & Skripte**: Siehe [`documentation/origin/`](documentation/origin/) ([Executive Summary](documentation/origin/ORIGIN_SUMMARY.md), [Technical Writeup](documentation/origin/TECHNICAL_WRITEUP.md) & Azure CLI Skripte).

### 2. [Projekt 2: LearningSteps Evolution](02_learningsteps_evolution.md) (Steps 1–5 Abgeschlossen ✅)
* **Ziel**: Transformation von skriptbasierter VM-Infrastruktur hin zu einem vollständig automatisierten, gehärteten Cloud-Native DevOps-Lebenszyklus.
* **Umgesetzte Bausteine**:
  1. **Containerisierung**: Gehärtetes [`Dockerfile`](Dockerfile) (Non-Root `apiuser`, gepatchte OS-Pakete, Entfernung von `pip`/`setuptools`/`ensurepip` nach dem Build).
  2. **Infrastructure as Code (IaC)**: Deklarative Azure-Infrastruktur unter [`infra-terraform/`](infra-terraform/) (VNet, Subnetze, AKS mit CSI Secrets Provider, Flexible PostgreSQL, Key Vault, ACR & `AcrPull`-RBAC) mit Azure Storage Remote State.
  3. **DevSecOps**: Automatisierte Scans in [`trivy.yml`](.github/workflows/trivy.yml) (Terraform, K8s-Manifeste, Container-Image, Secrets → SARIF), Python-SAST via [`codeql.yml`](.github/workflows/codeql.yml) sowie Linting/Tests via [`lint.yml`](.github/workflows/lint.yml).
  4. **CI/CD & OIDC**: Passwortloser Azure-Login via OIDC, manuelles Release-Tagging ([`tag.yml`](.github/workflows/tag.yml)), automatisches Deployment ([`deploy.yml`](.github/workflows/deploy.yml)) und sicherer Cleanup ([`destroy.yml`](.github/workflows/destroy.yml)).
  5. **Container-Orchestrierung**: Manifeste unter [`k8s-manifests/`](k8s-manifests/) inkl. Pod/Container-`securityContext`, `ConfigMap`, Azure Key Vault `SecretProviderClass` und `HorizontalPodAutoscaler`.
  6. *(Optional)* **Observability**: Prometheus-Metriken & Grafana-Dashboards (Ausblick Step 6).
* **Dokumentation**: Siehe [`documentation/evolution/`](documentation/evolution/) ([Executive Summary](documentation/evolution/EVOLUTION_SUMMARY.md), [Verlaufsjournal](documentation/evolution/EVOLUTION_JOURNAL.md), [Evolution-Übersicht](documentation/evolution/README.md) & [Roadmap](documentation/evolution/ROADMAP.md)).

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

3. **API starten & Smoke-Test ausführen**:
   ```bash
   ./start.sh
   # oder: uvicorn api.main:app --reload --port 8000

   # Smoke-Test (ohne DB)
   PYTHONPATH=api DATABASE_URL=postgresql://test:test@localhost:5432/testdb pytest tests/ -v
   ```
