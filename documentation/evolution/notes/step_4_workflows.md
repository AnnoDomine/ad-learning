# Step 4 – GitHub Actions CI/CD, DevSecOps & OIDC

## 1. Architektur-Entscheidung: Logisch getrennte Workflows

Statt einer monolithischen Pipeline, die bei jedem Push die komplette Cloud-Infrastruktur anfasst, wurden die Verantwortlichkeiten gemäß [`ROADMAP.md`](../ROADMAP.md) in **sechs spezialisierte Workflows** unter [`.github/workflows/`](../../../.github/workflows/) aufgeteilt:

| Workflow | Datei | Trigger | Aufgabe |
| :--- | :--- | :--- | :--- |
| **Code-Qualität** | [`lint.yml`](../../../.github/workflows/lint.yml) | `push` / `pull_request` auf `main`, `workflow_dispatch` | Ruff Linting & Formatting + Pytest Smoke-Test mit Coverage |
| **Security Gates** | [`trivy.yml`](../../../.github/workflows/trivy.yml) | `push` / `pull_request` auf `main`, `workflow_dispatch` | Trivy-Scans (`CRITICAL,HIGH`) für Terraform, K8s, Docker-Image & Secrets + SARIF-Upload |
| **Python SAST** | [`codeql.yml`](../../../.github/workflows/codeql.yml) | `push` / `pull_request` auf `main`, wöchentlicher Cron | GitHub CodeQL Statische Codeanalyse für Python |
| **Release-Tagging** | [`tag.yml`](../../../.github/workflows/tag.yml) | `workflow_dispatch` (nur auf `main`) | Erstellt & pusht annotierten Git-Tag `v<version>` nach Duplikat-Prüfung |
| **Build & Deploy** | [`deploy.yml`](../../../.github/workflows/deploy.yml) | `push.tags: "v*.*.*"`, `workflow_dispatch` | OIDC-Login, Remote-State-Setup, Terraform Apply, ACR-Push, AKS-Deploy & Health-Check |
| **Teardown / Cleanup** | [`destroy.yml`](../../../.github/workflows/destroy.yml) | `workflow_dispatch` (`confirm == 'DESTROY'`) | Vollständiger Infrastruktur-Abbau inkl. optionaler State-RG-Bereinigung |

### Leitprinzipien für alle Workflows
* **Supply-Chain-Schutz (SHA-Pinning):** Alle Actions (z. B. `actions/checkout`, `azure/login`, `hashicorp/setup-terraform`, `azure/setup-kubectl`, `astral-sh/ruff-action`, `actions/setup-python`) werden auf ihren vollständigen 40-stelligen Commit-SHA gepinnt und mit Versionskommentar dokumentiert.
* **Least Privilege (`permissions`):** Lese-/Prüfjobs erhalten ausschließlich `contents: read`; nur `tag.yml` benötigt `contents: write`, und nur `deploy.yml` / `destroy.yml` erhalten `id-token: write` für Azure OIDC.
* **Passwortloses Azure OIDC:** Statt statischer Service-Principal-Secrets nutzt die Pipeline OpenID Connect gebunden an das GitHub-Environment **`production`**.

---

## 2. Details zu den einzelnen Pipelines

### 2.1 `lint.yml` – Ruff & Pytest Smoke-Test
* **`ruff`-Job:** Prüft `learningsteps/api/` via `astral-sh/ruff-action` und validiert das Code-Format über `ruff format --check --diff` im Verzeichnis `learningsteps/`. Eine projektspezifische [`ruff.toml`](../../../learningsteps/ruff.toml) ignoriert gezielt `B008` (FastAPIs `Depends(...)` in Parameter-Defaults).
* **`pytest`-Job:** Nutzt Python `3.13`, installiert `api/requirements.txt` sowie `pytest`, `coverage` und `httpx`.
  * Da `postgres_repository.py` bereits beim Modul-Import auf `DATABASE_URL` prüft, wird für die CI-Umgebung eine Dummy-URL (`postgresql://test:test@localhost:5432/testdb`) injiziert.
  * Der Aufruf `PYTHONPATH=api coverage run -m pytest tests/ -v -s` zielt bewusst auf [`learningsteps/tests/test_smoke.py`](../../../learningsteps/tests/test_smoke.py), damit das manuelle Dozenten-Skript [`test_api.py`](../../../learningsteps/test_api.py) nicht als Pytest-Suite eingesammelt wird.

### 2.2 `trivy.yml` – Automatisierte Security Gates & SARIF
* Vier parallele Scan-Jobs prüfen **Terraform (`infra-terraform`)**, **Kubernetes-Manifeste (`k8s-manifests`)**, das gebaute **Docker-Image (`learningsteps:test`)** und **Secrets im Repository**.
* **Wichtige Erkenntnis (`limit-severities-for-sarif: true`):** Im `sarif`-Format wertet `aquasecurity/trivy-action` das `severity`-Filter ohne dieses Flag nicht für den Exit-Code aus, sodass bereits `MEDIUM`/`LOW`-Hinweise zu `exit-code: "1"` führten. Mit `limit-severities-for-sarif: true` und `ignore-unfixed: true` beim Image-Scan blockieren gezielt nur behebbare `HIGH`/`CRITICAL`-Schwachstellen.
* Der abschließende Job `upload-sarif-reports` führt alle vier Artefakte zusammen und lädt sie unter eigenen Kategorien in den **GitHub Security → Code Scanning** Tab hoch.

### 2.3 `deploy.yml` – End-to-End Provisionierung & Rollout
1. **Job `terraform`:**
   * Authentifiziert via `azure/login` (OIDC, `environment: production`).
   * Prüft kaskadierend und idempotent, ob Resource Group, Storage Account (`TLS1_2`, `allow-blob-public-access false`, `enable-versioning true`) und `tfstate`-Container existieren, und legt fehlende Teile automatisch an.
   * Initialisiert Terraform mit `-backend-config` und `use_azuread_auth=true`.
   * Führt einen **Pre-Plan-Firewall-Step** aus: Existiert der Key Vault bereits im State, wird die aktuelle Runner-IP vor `terraform plan` freigeschaltet, um `ForbiddenByFirewall` beim State-Refresh zu vermeiden.
   * Wendet `terraform apply` mit der dynamischen Runner-IP (`TF_VAR_aks_authorized_ip_ranges`) an und autorisiert anschließend auch die **effektive Outbound-IP des AKS-Clusters** in der Key-Vault-Firewall.
   * Exportiert alle Outputs dynamisch nach `$GITHUB_OUTPUT` sowie in die `$GITHUB_STEP_SUMMARY`.
2. **Job `deploy` (`needs: [terraform]`):**
   * Baut das Image, meldet sich via `az acr login` an der ACR an und pusht das Image mit dem aktuellen Git-Tag (`${{ github.ref_name }}`).
   * Aktualisiert die AKS API-Server-Firewall auf die IP der neuen Runner-VM, holt `kubeconfig`, ersetzt die `${...}`-Platzhalter in `configmap.yaml` und `secret-provider-class.yaml` via `envsubst` (wobei `TENANT_ID` direkt aus `secrets.AZURE_TENANT_ID` stammt, da GitHub Actions Outputs mit Secret-Werten automatisch maskiert/leert), wendet die Manifeste an und wartet mit `kubectl rollout status --timeout=180s`.
3. **Job `health-check` (`needs: [terraform, deploy]`):**
   * Schaltet die eigene Runner-IP für AKS frei, pollt bis zu 3 Minuten (18×10 s) auf die vom Azure LoadBalancer zugewiesene Public IP von `learningsteps-api-service`, prüft `curl -fsS http://${EXTERNAL_IP}/docs` auf HTTP 200 und schreibt die Live-URL in die `$GITHUB_STEP_SUMMARY`.

### 2.4 `destroy.yml` – Kontrollierter Rückbau & Recovery
* Erfordert die manuelle Eingabe von `"DESTROY"` im `confirm`-Input (`if: inputs.confirm == 'DESTROY'`).
* Schaltet die Runner-IP vorab auf dem Key Vault frei, führt `terraform destroy -auto-approve` aus und löscht erst nach erfolgreichem Teardown (`steps.destroy_tf_aks.outcome == 'success'`) auch die separate `tfstate`-Resource-Group.

---

## 3. OIDC-Einrichtung (Bootstrap-Skript)

Für die erstmalige Einrichtung der Workload Identity Federation existiert [`documentation/evolution/scripts/tfstate_oidc.sh`](../scripts/tfstate_oidc.sh). Es weist der Entra-ID-App exakt die drei benötigten Rollen zu (`Contributor`, `Storage Blob Data Contributor`, `User Access Administrator`) und ermittelt über `gh api repos/{owner}/{repo}` den exakten GitHub-OIDC-Subject-Claim inklusive numerischer Owner- und Repo-ID:
```text
repo:AnnoDomine@6992858/ad-learning@1437016446:environment:production
```

## 4. Lokale Verifikation

```bash
cd learningsteps
ruff check api/
ruff format --check --diff .
PYTHONPATH=api DATABASE_URL=postgresql://test:test@localhost:5432/testdb pytest tests/ -v
```
