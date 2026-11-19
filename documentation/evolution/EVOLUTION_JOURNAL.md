# 📜 Verlaufsdokumentation: LearningSteps Evolution (Step-by-Step)

Dieses Dokument zeichnet den chronologischen Entwicklungs-, Härtungs- und Troubleshooting-Verlauf von **Projekt 2 (LearningSteps Evolution)** auf Basis der Git-Historie und der einzelnen Umsetzungsetappen vom **05.11.2026 bis 19.11.2026** nach.

---

## 1. Ausgangslage & Architektur-Entscheidungen

Nach Abschluss von **Projekt 1 (Origin)** (klassische 2-Tier-VM-Architektur mit Nginx-WAF und Azure CLI Bash-Skripten) galt es, die FastAPI-Anwendung in einen Cloud-Native-, Container- und DevSecOps-Lebenszyklus zu überführen (vgl. [`02_learningsteps_evolution.md`](../../02_learningsteps_evolution.md)).

Zu Projektbeginn wurden in der [`ROADMAP.md`](ROADMAP.md) zwei bewusste Architektur-Entscheidungen getroffen:

1. **Saubere Root-Struktur:** Automatisierungs-Artefakte (`Dockerfile`, `infra-terraform/`, `k8s-manifests/`, `.github/workflows/`) liegen im Repository-Root getrennt vom Anwendungscode in [`learningsteps/`](../../learningsteps/).
2. **Aufgeteilte CI/CD-Pipelines:** Statt eines einzigen Workflows auf `every push` wurden logisch getrennte Pipelines mit gezielten Triggern (`main`-PRs für Lint/Security, manuelle Tags für Deployments, manuelles `DESTROY`-Gate für Cleanup) eingeführt.

---

## 2. Chronologischer Projektverlauf

### Etappe 1 – Containerisierung & manuelles ACR-Deployment (05.11.2026)

* Erstellung des ersten [`Dockerfile`](../../Dockerfile) auf Basis von `python:3-slim` mit dediziertem Non-Root-User (`apiuser`), getrenntem `requirements.txt`-Layer-Caching und Uvicorn auf Port `8000`.
* Anlage der ersten Bootstrap-Skripte unter [`documentation/evolution/scripts/`](scripts/) (`docker.sh`, `acr.sh`, `evolution.sh`, `params.sh`) zur Verifikation eines manuellen Docker-Builds und ACR-Pushes.
* Dokumentiert in [`notes/step_1_docker.md`](notes/step_1_docker.md).

### Etappe 2 – Infrastructure as Code mit Terraform (06.11.2026)

* Aufbau des deklarativen Terraform-Stacks unter [`infra-terraform/`](../../infra-terraform/):
  * `azurerm_resource_group` (`learningsteps-evo-lab-rg`, Region `westeurope`)
  * `azurerm_virtual_network` (`10.0.0.0/16`) & delegiertes Subnetz (`10.0.2.0/24`) für PostgreSQL inkl. `Microsoft.Storage`-Service-Endpoint
  * `azurerm_private_dns_zone` & VNet-Link für interne Datenbank-Namensauflösung
  * `azurerm_key_vault` (Premium SKU) mit generiertem `random_password` als Secret `db-admin-password` sowie rotiertem RSA-Key
  * `azurerm_kubernetes_cluster` (`learningsteps-evo-akcc`) mit `SystemAssigned`-Identity
  * `azurerm_postgresql_flexible_server` (PostgreSQL 18, `public_network_access_enabled = false`)
* Dokumentiert in [`notes/step_2_iac.md`](notes/step_2_iac.md).

### Etappe 3 – DevSecOps-Scans & Erst-Analyse mit Trivy (06.–09.11.2026)

* Einführung von [`generate_trivy_logs.sh`](../../generate_trivy_logs.sh) und Aufbau der GitHub-Actions-Pipeline [`.github/workflows/trivy.yml`](../../.github/workflows/trivy.yml) mit SARIF-Export in den GitHub Security Tab.
* Erste Baseline-Messung (dokumentiert in [`notes/step_3_security.md`](notes/step_3_security.md) und [`output/trivy/terraform.log`](output/trivy/terraform.log)):
  * **Terraform IaC:** 19 Findings (davon **3 CRITICAL, 2 HIGH**: `AZU-0012`, `AZU-0013`, `AZU-0041`, `AZU-0042`, `AZU-0043`)
  * **Docker Image (`python:3-slim`):** 186 Findings (davon **49 HIGH**)
  * **Secrets-Scan (`fs`):** 0 Secrets geleakt.
* Ergänzung von GitHub CodeQL ([`codeql.yml`](../../.github/workflows/codeql.yml)) für Python-SAST.

### Etappe 4 – CI/CD-Pipelines, Ruff/Pytest & Hardening-Welle (18.11.2026)

* **Qualitäts-Pipeline ([`lint.yml`](../../.github/workflows/lint.yml)):**
  * Einrichtung von Ruff (`astral-sh/ruff-action` per Commit-SHA gepinnt) + Format-Check. Bestehende Stil-/Modernisierungs-Meldungen im Dozenten-Code wurden per `ruff check --fix` und `ruff format` bereinigt; FastAPIs idiomatisches `Depends()` über [`learningsteps/ruff.toml`](../../learningsteps/ruff.toml) (`ignore = ["B008"]`) sowie `# noqa: BLE001` gezielt adressiert.
  * Aufbau eines datenbankfreien Pytest-Smoke-Tests ([`learningsteps/tests/test_smoke.py`](../../learningsteps/tests/test_smoke.py)) inklusive Dummy-`DATABASE_URL` für das Modul-Import-Verhalten von `postgres_repository.py`.
* **Release & Teardown ([`tag.yml`](../../.github/workflows/tag.yml) & [`destroy.yml`](../../.github/workflows/destroy.yml)):**
  * Kontrolliertes Semantic-Tagging ausschließlich auf `main` sowie gesicherter `DESTROY`-Workflow für Infrastructure Recovery und Kostenkontrolle.
* **Terraform & Remote State Hardening:**
  * Auslagerung des `tfstate`-Storage-Accounts aus `main.tf` in einen idempotenten Azure-CLI-Pre-Step in `deploy.yml` (verhindert das Henne-Ei-Problem bei `init` und Selbstlöschung bei `destroy`), aktiviert mit `backend "azurerm" {}` und `use_azuread_auth=true`.
  * Behebung aller 5 `HIGH`/`CRITICAL`-IaC-Blocker (`AZU-0012` entfernt; `AZU-0013` Key-Vault-Firewall `default_action = "Deny"`; `AZU-0041` AKS API IP-Ranges; `AZU-0042` RBAC enabled; `AZU-0043` Azure Network Policy) → **0 Blocker**.
  * Integration von `azurerm_container_registry` (`admin_enabled = false`) und `AcrPull`-Role-Assignment in `main.tf` sowie Aktivierung des AKS `key_vault_secrets_provider` + `Microsoft.KeyVault`-Service-Endpoint.
* **Container & Trivy-Pipeline Hardening:**
  * Entdeckung und Behebung des SARIF-Verhaltens in `trivy-action` (`limit-severities-for-sarif: true` + `ignore-unfixed: true`).
  * Härtung des [`Dockerfile`](../../Dockerfile): Pinning auf `python:3.13-slim`, OS-Upgrade (`apt-get upgrade` für `zlib1g`), Erzwingung gepatchter Python-Pakete (`msgpack>=1.2.3`, `urllib3>=2.8.0`) sowie Deinstallation von `pip`, `setuptools` und `ensurepip` zur Beseitigung vendored CVEs → **Image-Scan grün**.

### Etappe 5 – Kubernetes-Orchestrierung, Live-Deployment & Recovery-Verifikation (18.11.2026)

* Erstellung der 5 Manifeste unter [`k8s-manifests/`](../../k8s-manifests/) (`configmap.yaml`, `secret-provider-class.yaml`, `deployment.yaml`, `service.yaml`, `hpa.yaml`) mit `envsubst`-Injektion in `deploy.yml`.
* Integration von `k8s-manifests/` in `trivy.yml` und Härtung von `deployment.yaml` (`KSV-0014` & `KSV-0118`: `readOnlyRootFilesystem: true`, `allowPrivilegeEscalation: false`, `capabilities.drop: [ALL]`, `runAsNonRoot: true`, `runAsUser: 1000`, `RuntimeDefault` seccomp) → **0 K8s-Blocker**.
* **Live-Durchlauf & Verifikation:**
  * End-to-End-Deployment via Release-Tag erfolgreich abgeschlossen; der `health-check`-Job bestätigte die öffentliche Erreichbarkeit der FastAPI Swagger UI unter **`http://20.71.5.147/docs`**.
  * Anschließend erfolgreicher Test von [`destroy.yml`](../../.github/workflows/destroy.yml) als Nachweis für sauberen Rückbau und Infrastructure Recovery.
* Konsolidierung der Projektdokumentation in [`documentation/origin/`](../origin/) und [`documentation/evolution/`](.).

### Etappe 6 – Abschlussdokumentation, In-Deep-Review & SKU-Härtung (19.11.2026)

* Durchgängige englische Inline-Dokumentation aller Terraform-, Kubernetes-, Dockerfile-, Workflow- und Skript-Artefakte gemäß [`AGENTS.md`](../../AGENTS.md).
* Vervollständigung der Verlaufsnotizen ([`step_4_workflows.md`](notes/step_4_workflows.md), [`step_5_kubernetes.md`](notes/step_5_kubernetes.md)), dieser Chronik sowie der offiziellen [`EVOLUTION_SUMMARY.md`](EVOLUTION_SUMMARY.md).
* Beim erneuten Recovery-Deployment am Morgen traten in `westeurope` regionale Kapazitätsengpässe (`SkuNotAvailable` bei `B_Standard_B1ms` und `B_Standard_B2s`) sowie eine Provider-Regex-Ablehnung bei `B_Standard_B2als_v2` auf; die PostgreSQL-SKU wurde daraufhin stabil auf `GP_Standard_D2ds_v5` umgestellt.

---

## 3. Troubleshooting- & Lessons-Learned-Protokoll

Während des Projekts traten neun reale Cloud-/DevSecOps-Fehlerbilder auf, die systematisch analysiert und dauerhaft in Code & Pipeline gelöst wurden:

| # | Fehlerbild / Symptom | Ursache (Root Cause) | Dauerhafte Lösung |
| :-: | :--- | :--- | :--- |
| **1** | `AADSTS700213` beim Azure OIDC Login | GitHub inkludierte numerische IDs im `sub`-Claim (`repo:AnnoDomine@6992858/ad-learning@1437016446:environment:production`) | `subject` im Entra-ID-Credential exakt angepasst; automatische Abfrage via `gh api` in [`tfstate_oidc.sh`](scripts/tfstate_oidc.sh) verankert |
| **2** | `AccountNameInvalid` beim Storage Account | `TF_STATE_STORAGE` enthielt unerlaubte Zeichen / Überlänge | Auf 3–24 alphanumerische Kleinbuchstaben (`a-z0-9`) korrigiert |
| **3** | `403 AuthorizationFailed` bei `roleAssignments/write` | OIDC-Principal besaß nur `Contributor` + `Storage Blob Data Contributor` | Rolle `User Access Administrator` für die Subscription ergänzt (nötig für AKS→ACR `AcrPull`) |
| **4** | `403 ForbiddenByFirewall` bei `terraform plan` auf Key Vault | Jede GitHub-Runner-VM hat eine neue Public IP; `plan` liest den Key Vault *vor* `apply` | Pre-Plan-Step in `deploy.yml`/`destroy.yml` schaltet die aktuelle Runner-IP vorab via `az keyvault network-rule add` frei |
| **5** | PostgreSQL Update-Fehler zu `zone` bei Re-Apply | Azure weist bei Erstellung automatisch eine Zone zu, die Terraform als Drift entfernen will | `lifecycle { ignore_changes = [zone] }` in `azurerm_postgresql_flexible_server` ergänzt |
| **6** | CSI-Mount-Fehler `tenantId is not provided` | GitHub Actions filtert/leert Job-Outputs automatisch, wenn der Wert einem Secret (`AZURE_TENANT_ID`) entspricht | `TENANT_ID` im `deploy`-Job direkt aus `${{ secrets.AZURE_TENANT_ID }}` bezogen |
| **7** | CSI-Mount `403 ForbiddenByFirewall` von AKS-Node-IP `50.85.91.131` | AKS-Nodes laufen außerhalb des PostgreSQL-delegierten Subnetzes mit eigener Outbound-IP | `deploy.yml` liest `effectiveOutboundIPs` des AKS-Clusters aus und autorisiert sie automatisch am Key Vault |
| **8** | Pod-Startfehler `non-numeric user (apiuser)` bei `runAsNonRoot: true` | Kubernetes kann vor Start keine symbolischen Namen aus `/etc/passwd` verifizieren | Explizites `runAsUser: 1000` / `runAsGroup: 1000` im Pod-`securityContext` ergänzt |
| **9** | `SkuNotAvailable` in `westeurope` (`B_Standard_B1ms`, `B_Standard_B2s`) & `invalid value for sku_name` bei `B_Standard_B2als_v2` | Temporäre regionale Rack-Kapazitätsengpässe bei älteren Burstable-v1-SKUs (von `az postgres flexible-server list-skus` nicht abgebildet) sowie eine feste SKU-Regex-Validierung im `azurerm`-Provider (`~> 5.13.0`), die brandneue v2-Burstable-Namen noch abweist | Umstellung auf moderne, provider-validierte v5-Hardware (`GP_Standard_D2ds_v5`) und lokaler Pre-Check via `terraform validate` |
