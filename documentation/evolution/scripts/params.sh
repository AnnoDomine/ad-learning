#!/usr/bin/env bash
# ==============================================================================
# Legacy Step-1 Parameters – Manual Docker & ACR Bootstrap
# ==============================================================================
# Shared environment variables used by `docker.sh`, `acr.sh`, and `evolution.sh`
# during Step 1 (initial manual containerization & ACR push). Superseded in
# Steps 2-5 by Terraform (`infra-terraform/`) and GitHub Actions (`deploy.yml`).

export RG="learningsteps-evo-lab-rg"
export REGION="germanywestcentral"
export VNET="learningsteps-evo-vnet"
export ACR="${ACR:-learningstepsevoacr$(openssl rand -hex 4)}"
export CONTAINER="learningsteps"
export CURRENT_VERSION="${CURRENT_VERSION:-v0.1.0}"
export CONTAINER_LINK="$ACR.azurecr.io/${CONTAINER}:$CURRENT_VERSION"

# Repository and subdirectory paths for application deployment
export REPO_URL="${REPO_URL:-https://github.com/AnnoDomine/ad-learning.git}"
export REPO_BRANCH="${REPO_BRANCH:-main}"
export REPO_SUBDIR="${REPO_SUBDIR:-learningsteps}"

# Database and application credentials (sourced from environment variables / secrets)
export POSTGRES_USER="${POSTGRES_USER:-postgres}"
export POSTGRES_PASSWORD="${POSTGRES_PASSWORD:-}"
export POSTGRES_DB="${POSTGRES_DB:-learning_journal}"

# Alerting configuration (sourced from environment variables / secrets)
export ALERT_EMAIL="${ALERT_EMAIL:-}"
