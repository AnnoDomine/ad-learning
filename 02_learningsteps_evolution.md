# LearningSteps Evolution

## Project brief

Welcome back, Cloud Architect!

You’ve built the foundation. You’ve manually provisioned servers and wired up networking in Azure. But in the world of modern engineering, _manual is a bottleneck_.

It is time to evolve the LearningSteps API 'Learningsteps' from a static deployment into a self-healing, automated, and observable ecosystem.

**_You have 4 weeks to complete this project._**

## The Evolution: From Manual to Automated

Your mission is to take the existing 2-tier LearningSteps application and wrap it in a professional DevOps lifecycle. We are moving away from "hand-crafted" Virtual Machines and toward **Cloud-Native Orchestration**.

In the first LearningSteps project you built a 2-tier architecture by hand - you clicked through the Azure Portal, created Virtual Machines, configured Network Security Groups, installed PostgreSQL manually, and deployed the FastAPI app via SSH. You learned what each piece does by touching it directly.

Now it is time to evolve. This project takes the same LearningSteps application and wraps it in a professional DevOps lifecycle. Instead of clicking in the Azure Portal, you will:

- **Define infrastructure in code (Terraform)** - so you can recreate everything with one command
- **Package the application in a container (Docker)** - so it runs the same everywhere
- **Orchestrate containers (Kubernetes / AKS)** - so the app self-heals and scales
- **Automate everything (GitHub Actions)** - so every git push triggers build, scan, and deploy
- **Monitor the application (Prometheus & Grafana)** - so you can see what is happening inside

> You don’t need to use previous project you have created 2 weeks ago. You will just use Learningsteps repo get original app code and deploy it a completely new way.

## Capstone Overview

You will build a fully automated pipeline that manages the entire lifecycle of LearningSteps:

- **Infrastructure**: Provisioned via Code (Terraform).
- **Packaging**: Standardized via Containers (Docker).
- **Orchestration**: Managed via Azure Kubernetes Service (AKS).
- **Delivery**: Automated via GitHub Actions with integrated security.
- **Health**: Visualized via Prometheus & Grafana.

![capstone](https://cybersteps-prod-uploads.fra1.digitaloceanspaces.com/assets/c7/c7a225c735e72177828e34b8c84fa9a583f3f48f3b1ff9e02a462dcb65adef22.png)

## Skills Checklist

- **Containerization**: Write a production-grade Dockerfile.
- **Infrastructure as Code**: Provision Azure resources using Terraform.
- **DevSecOps**: Implement security scanning within the CI/CD pipeline.
- **CI/CD**: Automate the "Build-Scan-Deploy" loop with GitHub Actions.
- **Orchestration**: Deploy and manage pods in Azure Kubernetes Service (AKS).
- **(Optional) Observability**: Monitor application health with Prometheus and Grafana.

## Your Mission Brief

1 **Containerize the Application**

> No more "it works on my machine." Package the FastAPI app into a lightweight, production-grade container.

- Write a Dockerfile for the LearningSteps API.
- Build and run the container locally using Docker Desktop to verify functionality.
- Push your image to an Azure Container Registry (ACR).

2 **Infrastructure as Code (IaC)**

> Put down the Azure Portal mouse! You will now define your entire environment using Terraform.

- **Networking**: Define a VNET with dedicated subnets for AKS and the Database.
- **Compute**: Provision an Azure Kubernetes Service (AKS) cluster.
- **Data**: Provision an Azure Database for PostgreSQL (Flexible Server).
- **Security**: Manage Azure Key Vault for sensitive connection strings.

3 **Securing the Pipeline (DevSecOps)**

> Security is no longer a final step; it's integrated into every commit.

- **Secret Scanning**: Use GitHub's secret scanning or a tool like trufflehog to ensure no Azure credentials or DB passwords are committed to the repo.
- **Vulnerability Scanning**: Add a step in your pipeline to scan your Docker image for vulnerabilities using Trivy or Snyk before pushing to ACR.
- **IaC Static Analysis**: Use tfsec , checkov or trivy to scan your Terraform files for security misconfigurations (e.g., open ports or missing encryption).

4 **CI/CD Pipeline**

> Automate the mundane. Create a GitHub Actions workflow that triggers on every git push.

- **Build Stage**: Lint the Python code, run tests, and build the Docker image.
- **Security Stage**: Run your vulnerability and IaC scans. If a "High" or "Critical" issue is found, the pipeline must fail.
- **Push Stage**: Authenticate with Azure and push the verified image to ACR.
- **Deploy Stage**: Update the AKS cluster to pull the latest image and restart the deployment.

5 **Kubernetes Orchestration**

> Deploy LearningSteps to AKS to ensure high availability and scalability.

- **Manifests**: Write Deployment, Service (LoadBalancer), and ConfigMap YAML files.
- **Secrets**: Integrate Azure Key Vault secrets into your Kubernetes pods.
- **Scalability**: Configure horizontal pod autoscaling to handle traffic spikes.

6 **(Optional) Monitoring & Observability**

> We haven’t covered this in class, but you are encouraged to try implementing this part as well!
> If you can't measure it, you can't manage it.

- **Metrics**: Instrument the FastAPI app using prometheus_client.
- **Stack**: Deploy Prometheus and Grafana into your AKS cluster.
- **Dashboard**: Create a Grafana dashboard visualizing HTTP Request Volume, API Latency, and Database health.

## Example Project Structure

```bash
/learningsteps
  /infra-terraform      # Terraform (.tf) files for Azure resources
  /k8s-manifests        # Kubernetes YAML (Deployment, Service, Ingress)
  /app                  # FastAPI source code
  Dockerfile            # Container definition
  .github/workflows/    # GitHub Actions CI/CD with Security Scans
  README.md             # Your technical writeup
```

## Success Criteria

| Done | Topic | Criteria |
| :-: | :-- | :-- |
| [ ] | Continuous Deployment | Push a code change and see it live on your Azure public IP automatically. |
| [ ] | Security Enforcement | Prove your pipeline fails if you introduce a vulnerable package or an insecure Terraform rule. |
| [ ] | Infrastructure Recovery | Run terraform destroy and terraform apply to recreate the entire environment. |
| [ ] | (Optional) Visual Insights | Show a live Grafana dashboard populated with real metrics from your API. |

> It is a 4 weeks project and it is supposed to be challenging. Research the documentation and treat every error message as a clue. Good luck!