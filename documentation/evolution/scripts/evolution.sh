#!/usr/bin/env bash
set -euo pipefail

# 0. Parameter laden
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if [ -f "${SCRIPT_DIR}/params.sh" ]; then
  source "${SCRIPT_DIR}/params.sh"
else
  export RG="learningsteps-lab-rg"
  export REGION="germanywestcentral"
  export VNET="learningsteps-vnet"
  export ACR="learningstepsacr$(openssl rand -hex 4)"
  export CONTAINER="learningsteps"
  export CONTAINER_LINK="$ACR.azurecr.io/${CONTAINER}:$CURRENT_VERSION"
fi

# 1. Docker Image lokal bauen
"${SCRIPT_DIR}/docker.sh" 
  
# 2. ACR erstellen & Image pushen 
"${SCRIPT_DIR}/acr.sh" 