# Step 5 – Kubernetes-Orchestrierung (AKS), Key Vault CSI & Hardening

## 1. Übersicht der Kubernetes-Manifeste (`k8s-manifests/`)

Alle Kubernetes-Ressourcen liegen modular getrennt im Verzeichnis [`k8s-manifests/`](../../../k8s-manifests/) und werden über [`deploy.yml`](../../../.github/workflows/deploy.yml) vollautomatisch auf dem AKS-Cluster (`learningsteps-evo-akcc`) ausgerollt:

| Datei | Kubernetes-Ressource | Aufgabe |
| :--- | :--- | :--- |
| [`configmap.yaml`](../../../k8s-manifests/configmap.yaml) | `ConfigMap` (`learningsteps-config`) | Nicht-geheime DB-Verbindungsdaten (`POSTGRES_USER`, `POSTGRES_DB`, `POSTGRES_HOST`) |
| [`secret-provider-class.yaml`](../../../k8s-manifests/secret-provider-class.yaml) | `SecretProviderClass` (`azure-kv-learningsteps`) | Bindet `db-admin-password` via Azure Key Vault Secrets Store CSI Driver an |
| [`deployment.yaml`](../../../k8s-manifests/deployment.yaml) | `Deployment` (`learningsteps-api`) | Startet die gehärteten FastAPI-Pods inkl. Probes, CSI-Mount & `DATABASE_URL`-Aufbau |
| [`service.yaml`](../../../k8s-manifests/service.yaml) | `Service` (`learningsteps-api-service`) | Öffentlicher Azure `LoadBalancer` (Port `80` → Container-Port `8000`) |
| [`hpa.yaml`](../../../k8s-manifests/hpa.yaml) | `HorizontalPodAutoscaler` (`learningsteps-api-hpa`) | Skaliert `learningsteps-api` automatisch zwischen `2` und `5` Replicas bei > 70 % CPU |

---

## 2. Geheime Konfiguration via Azure Key Vault CSI Driver

Statt statischer Kubernetes-Secrets im Repository oder im Klartext liest AKS das Datenbank-Passwort direkt zur Laufzeit aus dem Azure Key Vault (`learningsteps-evo-kv`):

1. **Terraform-Vorbereitung ([`infra-terraform/main.tf`](../../../infra-terraform/main.tf)):**
   * Im AKS-Cluster ist `key_vault_secrets_provider { secret_rotation_enabled = true }` aktiviert.
   * Die automatisch erzeugte AKS-Secrets-Identität (`secret_identity[0]`) erhält im Key Vault eine eigene `access_policy` mit minimalen Rechten (`Get` auf Keys & Secrets).
   * In `deploy.yml` wird zusätzlich die effektive Outbound-IP des AKS-Clusters in der Key-Vault-Firewall (`network_acls`) freigeschaltet, da der Cluster in einem eigenen AKS-Managed-Subnetz (getrennt vom PostgreSQL-delegierten Subnetz) läuft.
2. **Synchronisation im Cluster (`secret-provider-class.yaml`):**
   * Die `SecretProviderClass` nutzt `useVMManagedIdentity: "true"` mit der `AKS_KV_IDENTITY_CLIENT_ID` und spiegelt `db-admin-password` über `secretObjects` in das Kubernetes-Secret `learningsteps-db-secret` (Key `DB_PASSWORD`).
   * Die Platzhalter `${AKS_KV_IDENTITY_CLIENT_ID}`, `${KEY_VAULT_NAME}`, `${TENANT_ID}` und `${DATABASE_FQDN}` werden in `deploy.yml` vor `kubectl apply` per `envsubst` injiziert.
3. **Dynamische `DATABASE_URL`-Komposition (`deployment.yaml`):**
   * Der Pod mountet das CSI-Volume unter `/mnt/secrets-store` (zwingend erforderlich, damit der CSI-Driver das Secret synct) und setzt `DATABASE_URL` per Kubernetes-Variablensubstitution zusammen:
     ```text
     postgresql://$(POSTGRES_USER):$(POSTGRES_PASSWORD)@$(POSTGRES_HOST):5432/$(POSTGRES_DB)?sslmode=require
     ```

---

## 3. Container- & Pod-Hardening (Trivy `KSV-*` auf `0`)

Ein initialer Trivy-Scan auf `k8s-manifests/` meldete **3 `HIGH`-Findings** in `deployment.yaml` (`KSV-0014` und zweimal `KSV-0118`). Durch einen gehärteten `securityContext` auf Pod- und Container-Ebene wurden alle Findings behoben:

* **Pod-Ebene (`template.spec.securityContext`):**
  * `runAsNonRoot: true`
  * `runAsUser: 1000` und `runAsGroup: 1000` *(zwingend als numerische UID/GID, da Kubernetes den Text-Benutzernamen `apiuser` aus dem Dockerfile vor Containerstart nicht gegen `/etc/passwd` prüfen kann)*
  * `seccompProfile.type: RuntimeDefault`
* **Container-Ebene (`containers[].securityContext`):**
  * `allowPrivilegeEscalation: false`
  * `readOnlyRootFilesystem: true` *(funktioniert reibungslos, da Uvicorn/FastAPI nur auf `stdout` loggt)*
  * `capabilities.drop: ["ALL"]`

---

## 4. Verfügbarkeit & Autoscaling

* **Probes:** `readinessProbe` (Startverzögerung 5 s, Intervall 10 s) und `livenessProbe` (15 s / 20 s) prüfen `HTTP GET /docs` auf Port `8000`, sodass `kubectl rollout status` erst bei voll initialisiertem ASGI-Server Erfolg meldet.
* **Ressourcen & HPA:** Mit `requests` (`100m` CPU / `128Mi` RAM) und `limits` (`500m` CPU / `256Mi` RAM) besitzt der `HorizontalPodAutoscaler` (`autoscaling/v2`) eine definierte Berechnungsbasis und hält stets mindestens 2 Pods (bis maximal 5 Pods bei 70 % CPU-Auslastung) aktiv.

---

## 5. Verifizierte Live-Ergebnisse

* Alle 5 Manifeste lassen sich ohne manuelle Eingriffe über `deploy.yml` ausrollen.
* Der `health-check`-Job ermittelte erfolgreich die zugewiesene LoadBalancer-IP (`http://20.71.5.147/docs`) und bestätigte die Erreichbarkeit mit HTTP 200.
* Der Rückbau via [`destroy.yml`](../../../.github/workflows/destroy.yml) sowie das erneute Deployment wurden vollständig verifiziert.
