# 📚 Projektdokumentation – LearningSteps

Die Dokumentation ist chronologisch in die beiden Projekt-Meilensteine unterteilt:

---

## 1️⃣ Teil 1: LearningSteps Origin (`origin/`)
*Klassische 2-Tier-Architektur auf Azure Virtual Machines (VM, Nginx/WAF, privates PostgreSQL-VNet, Azure CLI).*

* **[ORIGIN_SUMMARY.md](origin/ORIGIN_SUMMARY.md)** – Executive Summary & Projektergebnisse
* **[TECHNICAL_WRITEUP.md](origin/TECHNICAL_WRITEUP.md)** – Ausführlicher technischer Architekturbericht
* **[scripts/](origin/scripts/)** – Azure-CLI-Skripte (`init.sh`, `deploy.sh`, `pause_vms.sh`, `start_vms.sh`, `params.sh`)

---

## 2️⃣ Teil 2: LearningSteps Evolution (`evolution/`)
*Cloud-Native Transformation mit Docker, Terraform, GitHub Actions (OIDC & DevSecOps) und Azure Kubernetes Service (AKS).*

* **[evolution/EVOLUTION_SUMMARY.md](evolution/EVOLUTION_SUMMARY.md)** – Offizielle Projektzusammenfassung (inkl. Architekturdiagramm, Success Criteria & Screenshot-Nachweisen)
* **[evolution/EVOLUTION_JOURNAL.md](evolution/EVOLUTION_JOURNAL.md)** – Chronologische Step-by-Step-Verlaufsdokumentation & Troubleshooting-Log
* **[evolution/README.md](evolution/README.md)** – Architektur-, Pipeline- & Dokumentationsübersicht von Projekt 2
* **[evolution/ROADMAP.md](evolution/ROADMAP.md)** – Umsetzungsplan, Design-Entscheidungen & Abweichungen
* **[evolution/notes/](evolution/notes/)** – Detailnotizen zu den Etappen ([Step 1](evolution/notes/step_1_docker.md) bis [Step 5](evolution/notes/step_5_kubernetes.md))
* **[evolution/images/](evolution/images/README.md)** – Screenshot-Checkliste und Ablageort für Azure-/GitHub-Nachweise
* **[evolution/output/](evolution/output/)** – Gesammelte Scan- & Trivy-Logs
* **[evolution/scripts/](evolution/scripts/)** – Bootstrap- und OIDC-Skripte für Projekt 2
