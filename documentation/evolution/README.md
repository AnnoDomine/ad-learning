# 🚀 Teil 2: LearningSteps Evolution – Dokumentation

Dieses Verzeichnis bündelt die offizielle Abschlussdokumentation, das chronologische Verlaufsjournal sowie alle Konzepte, Notizen und Nachweise zur Cloud-Native-Transformation der LearningSteps API (vgl. [Aufgabenstellung](../../02_learningsteps_evolution.md)).

---

## 🗺️ Zentrale Dokumente

* **[EVOLUTION_SUMMARY.md](EVOLUTION_SUMMARY.md)** – Offizielle Projektzusammenfassung (Executive Summary, Zielarchitektur, Success Criteria Audit, Hardening & visuelle Nachweise)
* **[EVOLUTION_JOURNAL.md](EVOLUTION_JOURNAL.md)** – Chronologische Step-by-Step-Verlaufsdokumentation & 9-Punkte-Troubleshooting-Log
* **[ROADMAP.md](ROADMAP.md)** – Stufenplan, bewusste Architektur-Abweichungen (Root-Struktur, aufgeteilte Workflows) und Meilensteine
* **[images/README.md](images/README.md)** – Checkliste & Zielpfad für deine Azure-/GitHub-Screenshots
* **[output/](output/)** – Archivierte Trivy- & Scan-Protokolle
* **[scripts/](scripts/)** – OIDC-Bootstrap (`tfstate_oidc.sh`) und Step-1-Hilfsskripte

### 📝 Etappen-Notizen (`notes/`)

* **[notes/step_1_docker.md](notes/step_1_docker.md)** – Containerisierung & erstes manuelles ACR-Deployment
* **[notes/step_2_iac.md](notes/step_2_iac.md)** – Infrastructure as Code (Terraform)
* **[notes/step_3_security.md](notes/step_3_security.md)** – Initiale Security-Analyse & Baseline-Ergebnisse
* **[notes/step_4_workflows.md](notes/step_4_workflows.md)** – GitHub Actions CI/CD, DevSecOps & OIDC
* **[notes/step_5_kubernetes.md](notes/step_5_kubernetes.md)** – Kubernetes-Orchestrierung, Key Vault CSI & Pod-Hardening

---

## 🏗️ Architektur & Automatisierung im Überblick

| Bereich | Pfad / Workflow | Kernfunktion |
| :--- | :--- | :--- |
| **Container** | [`Dockerfile`](../../Dockerfile) | Python `3.13-slim`, Non-Root `apiuser`, gehärtet (ohne `pip`/`setuptools`/`ensurepip`) |
| **IaC** | [`infra-terraform/`](../../infra-terraform/) | VNet, Subnetz, AKS (mit CSI Secrets Provider), PostgreSQL Flexible Server, Key Vault, ACR |
| **Kubernetes** | [`k8s-manifests/`](../../k8s-manifests/) | `Deployment` (hardened `securityContext`), `LoadBalancer`, `ConfigMap`, `SecretProviderClass`, `HPA` |
| **Lint & Test** | [`.github/workflows/lint.yml`](../../.github/workflows/lint.yml) | Ruff (`check` + `format`) und Pytest Smoke-Test auf `push`/`pull_request` nach `main` |
| **Security** | [`.github/workflows/trivy.yml`](../../.github/workflows/trivy.yml) | Trivy-Scans (`CRITICAL,HIGH`) für Terraform, K8s-Manifeste, Docker-Image & Secrets + SARIF |
| **SAST** | [`.github/workflows/codeql.yml`](../../.github/workflows/codeql.yml) | GitHub CodeQL Analyse für Python |
| **Release** | [`.github/workflows/tag.yml`](../../.github/workflows/tag.yml) | Manuelles Semantic-Tagging (`v*.*.*`) auf `main` |
| **Deploy** | [`.github/workflows/deploy.yml`](../../.github/workflows/deploy.yml) | OIDC Login, Remote State Setup, `terraform apply`, ACR Push, `envsubst` + `kubectl apply`, Health-Check |
| **Cleanup** | [`.github/workflows/destroy.yml`](../../.github/workflows/destroy.yml) | Manuelles `terraform destroy` (mit `DESTROY`-Bestätigung) |
