#!/usr/bin/env bash
# ==============================================================================
# Bootstrap Script – Azure OIDC Workload Identity Federation for GitHub Actions
# ==============================================================================
# One-time setup script creating the Entra ID App Registration, Service
# Principal, RBAC role assignments, and Federated Identity Credential bound to
# the GitHub `production` environment (including numeric owner/repo IDs).
#
# Prerequisites: Authenticated `az login` and `gh auth login` inside this repo.

set -euo pipefail

# 1. Resolve active Azure subscription and Entra ID tenant
export AZURE_SUBSCRIPTION_ID
AZURE_SUBSCRIPTION_ID="$(az account show --query id -o tsv)"
export AZURE_TENANT_ID
AZURE_TENANT_ID="$(az account show --query tenantId -o tsv)"

# 2. Create Entra ID App Registration and ensure a Service Principal exists
export AZURE_CLIENT_ID
AZURE_CLIENT_ID="$(az ad app create --display-name "github-ad-learning-oidc" --query appId -o tsv)"

az ad sp create --id "$AZURE_CLIENT_ID" || true

# 3. Assign least-required subscription roles:
#    - Contributor: provision RG, VNet, AKS, PostgreSQL, Key Vault, ACR
#    - Storage Blob Data Contributor: Azure AD auth (`--auth-mode login`) for tfstate blobs
#    - User Access Administrator: let Terraform assign AcrPull RBAC to AKS kubelet identity
az role assignment create --assignee "$AZURE_CLIENT_ID" --role "Contributor" --scope "/subscriptions/$AZURE_SUBSCRIPTION_ID"
az role assignment create --assignee "$AZURE_CLIENT_ID" --role "Storage Blob Data Contributor" --scope "/subscriptions/$AZURE_SUBSCRIPTION_ID"
az role assignment create --assignee "$AZURE_CLIENT_ID" --role "User Access Administrator" --scope "/subscriptions/$AZURE_SUBSCRIPTION_ID"

# 4. Build exact GitHub OIDC subject claim (includes numeric owner & repo IDs)
SUBJECT_REPO="$(gh api repos/{owner}/{repo} --jq '"\(.owner.login)@\(.owner.id)/\(.name)@\(.id)"')"
SUBJECT="repo:${SUBJECT_REPO}:environment:production"

echo "Subject: $SUBJECT"

# 5. Register Federated Identity Credential for GitHub Actions `production` environment
FEDERATED_CREDENTIAL_JSON="$(cat <<EOF
{
  "name": "github-ad-learning-production",
  "issuer": "https://token.actions.githubusercontent.com",
  "subject": "${SUBJECT}",
  "description": "GitHub Actions OIDC for production environment",
  "audiences": ["api://AzureADTokenExchange"]
}
EOF
)"

az ad app federated-credential create \
  --id "$AZURE_CLIENT_ID" \
  --parameters "$FEDERATED_CREDENTIAL_JSON"

# Print values to store in GitHub Repository/Environment Secrets
echo "AZURE_CLIENT_ID=$AZURE_CLIENT_ID"
echo "AZURE_TENANT_ID=$AZURE_TENANT_ID"
echo "AZURE_SUBSCRIPTION_ID=$AZURE_SUBSCRIPTION_ID"
