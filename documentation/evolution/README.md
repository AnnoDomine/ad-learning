# 🚀 Teil 2: LearningSteps Evolution – Dokumentation

Dieses Verzeichnis bündelt alle Konzepte, Entscheidungen und Nachweise zur Cloud-Native-Transformation der LearningSteps API (vgl. [Aufgabenstellung](../../02_learningsteps_evolution.md)).

---

## 🗺️ Zentrale Dokumente
* **[ROADMAP.md](ROADMAP.md)** – Stufenplan, bewusste Architektur-Abweichungen (Root-Struktur, aufgeteilte Workflows) und Meilensteine
* **[notes/](notes/)** – Technische Notizen während der Umsetzung
* **[output/](output/)** – Archivierte Trivy- & Scan-Protokolle
* **[scripts/](scripts/)** – Hilfs- und Setup-Skripte

---

## 🏗️ Architektur & Automatisierung im Überblick

| Bereich | Pfad / Workflow | Kernfunktion |
| :--- | :--- | :--- |
| **Container** | [`Dockerfile`](../../Dockerfile) | Python `3.13-slim`, Non-Root `apiuser`, gehärtet (ohne `pip`/`setuptools`/`ensurepip`) |
| **IaC** | [`infra-terraform/`](../../infra-terraform/) | VNet, Subnetz, AKS (mit CSI Secrets Provider), PostgreSQL Flexible Server, Key Vault, ACR |
| **Kubernetes** | [`k8s-manifests/`](../../k8s-manifests/) | `Deployment` (hardened `securityContext`), `LoadBalancer`, `ConfigMap`, `SecretProviderClass`, `HPA` |
| **Lint & Test** | [`.github/workflows/lint.yml`](../../.github/workflows/lint.yml) | Ruff (`check` + `format`) und Pytest Smoke-Test auf `push`/`pull_request` nach `main` |
| **Security** | [`.github/workflows/trivy.yml`](../../.github/workflows/trivy.yml) | Trivy-Scans (`CRITICAL,HIGH`) für Terraform, Docker-Image, K8s-Manifeste & Secrets + SARIF |
| **Release** | [`.github/workflows/tag.yml`](../../.github/workflows/tag.yml) | Manuelles Semantic-Tagging (`v*.*.*`) auf `main` |
| **Deploy** | [`.github/workflows/deploy.yml`](../../.github/workflows/deploy.yml) | OIDC Login, Remote State Setup, `terraform apply`, ACR Push, `envsubst` + `kubectl apply`, Health-Check |
| **Cleanup** | [`.github/workflows/destroy.yml`](../../.github/workflows/destroy.yml) | Manuelles `terraform destroy` (mit `DESTROY`-Bestätigung) |
