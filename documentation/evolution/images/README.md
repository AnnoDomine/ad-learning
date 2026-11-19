# 📸 Screenshot-Checkliste für `EVOLUTION_SUMMARY.md`

Lege deine Azure-, GitHub- und Browser-Screenshots genau unter diesen Dateinamen in diesem Ordner (`documentation/evolution/images/`) ab – dann werden sie automatisch in [`EVOLUTION_SUMMARY.md`](../EVOLUTION_SUMMARY.md) eingebettet.

> **Datenschutz-Tipp:** Schwärze vor dem Commit gegebenenfalls deine Subscription-ID, Tenant-ID oder private E-Mail-Adresse auf den Screenshots.

| Nr. | Dateiname | Was der Screenshot zeigen sollte |
| :-: | :--- | :--- |
| **1** | `01_azure_resource_group.png` | **Azure Portal → Resource Group `learningsteps-evo-lab-rg`:** Übersicht aller per Terraform erstellten Ressourcen (AKS, PostgreSQL Flexible Server, Key Vault, ACR, VNet, Private DNS) |
| **2** | `02_azure_tfstate_storage.png` | **Azure Portal → Storage Account / Container (`tfstate`):** Automatisch angelegter Remote-State-Container inklusive `learningsteps.tfstate` und Blob-Versioning |
| **3** | `03_azure_aks_workloads.png` | **Azure Portal → AKS (`learningsteps-evo-akcc`) → Workloads / Services:** Laufende `learningsteps-api`-Pods (`Running`), HPA und der `LoadBalancer`-Service mit Public IP |
| **4** | `04_github_actions_pipelines.png` | **GitHub → Actions:** Übersicht der grünen Läufe für `Lint learningsteps`, `Security Scan (Trivy)`, `Release Tagging Pipeline` und `deploy` |
| **5** | `05_github_security_sarif.png` | **GitHub → Security → Code scanning:** Veröffentlichte SARIF-Reports (Terraform, K8s-Manifeste, Docker-Image, Secrets, CodeQL) ohne offene `HIGH`/`CRITICAL`-Blocker |
| **6** | `06_api_live_swagger_docs.png` | **Browser:** Live aufgerufene FastAPI Swagger UI (`http://<EXTERNAL-IP>/docs`, z. B. `http://20.71.5.147/docs`) als End-to-End-Nachweis |
| **7** | `07_destroy_pipeline_recovery.png` | **GitHub → Actions (`Destroy Infrastructure`):** Erfolgreicher `DESTROY`-Lauf inklusive geleerter Resource Group als Nachweis für *Infrastructure Recovery* & Kostenkontrolle |
