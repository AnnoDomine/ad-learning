#!/usr/bin/env bash
# ==============================================================================
# Legacy Step-1 Orchestrator – Build Local Image & Push to ACR
# ==============================================================================
# Combines `docker.sh` and `acr.sh` for the initial Step-1 manual proof of
# concept (superseded in Steps 2-5 by Terraform and GitHub Actions CI/CD).

set -euo pipefail

# 0. Load shared configuration (fallback to defaults if params.sh is absent)
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if [ -f "${SCRIPT_DIR}/params.sh" ]; then
  source "${SCRIPT_DIR}/params.sh"
else
  export RG="learningsteps-lab-rg"
  export REGION="germanywestcentral"
  export VNET="learningsteps-vnet"
  export ACR="learningstepsacr$(openssl rand -hex 4)"
  export CONTAINER="learningsteps"
  export CURRENT_VERSION="v0.1.0"
  export CONTAINER_LINK="$ACR.azurecr.io/${CONTAINER}:$CURRENT_VERSION"
fi

# 1. Build local Docker image
"${SCRIPT_DIR}/docker.sh"

# 2. Provision ACR & push image
"${SCRIPT_DIR}/acr.sh"
