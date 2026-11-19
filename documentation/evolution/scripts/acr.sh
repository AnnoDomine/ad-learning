#!/usr/bin/env bash
# ==============================================================================
# Legacy Step-1 Script – Manual ACR Provisioning & Image Push
# ==============================================================================
# Part of the initial Step-1 manual bootstrap (superseded in Steps 2-5 by
# `infra-terraform/main.tf` and `.github/workflows/deploy.yml`).

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/params.sh"

# Create Resource Group and Basic Azure Container Registry
az group create \
  --name "$RG" \
  --location "$REGION"

az acr create \
  --resource-group "$RG" \
  --name "$ACR" \
  --sku Basic \
  --location "$REGION"

# Authenticate Docker with ACR, push tagged image, and clean up local tag
az acr login --name "$ACR"

docker tag "$CONTAINER:$CURRENT_VERSION" "$CONTAINER_LINK"

docker push "$CONTAINER_LINK"

docker rmi "$CONTAINER_LINK"
