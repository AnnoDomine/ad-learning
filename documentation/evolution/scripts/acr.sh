#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/params.sh"

az rg create \
  --name $RG \
  --location $REGION

az acr create \
  --resource-group $RG \
  --name $ACR \
  --sku Basic \
  --location $REGION

  
az acr login --name $ACR

docker tag "$CONTAINER:$CURRENT_VERSION" "$CONTAINER_LINK" 

docker push "$CONTAINER_LINK"

docker rmi "$CONTAINER_LINK"
