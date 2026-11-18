#!/usr/bin/env bash
    set -euo pipefail

    # 1. Subscription & Tenant direkt aus dem aktuellen Login holen
    export AZURE_SUBSCRIPTION_ID=$(az account show --query id -o tsv)
    export AZURE_TENANT_ID=$(az account show --query tenantId -o tsv)

    # 2. App erstellen und client id nutzen
    export AZURE_CLIENT_ID=$(az ad app create --display-name "github-ad-learning-oidc" --query appId -o tsv)

    # Falls der Service Principal noch nicht existiert:
    az ad sp create --id "$AZURE_CLIENT_ID" || true

    # 3. Rollen zuweisen
    az role assignment create --assignee "$AZURE_CLIENT_ID" --role "Contributor" --scope "/subscriptions/$AZURE_SUBSCRIPTION_ID"
    az role assignment create --assignee "$AZURE_CLIENT_ID" --role "Storage Blob Data Contributor" --scope "/subscriptions/$AZURE_SUBSCRIPTION_ID"

    # 4. Federated Credential für GitHub OIDC (Environment: production)
    az ad app federated-credential create --id "$AZURE_CLIENT_ID" --parameters '{
      "name": "github-ad-learning-production",
      "issuer": "https://token.actions.githubusercontent.com",
      "subject": "repo:AnnoDomine/ad-learning:environment:production",
      "description": "GitHub Actions OIDC for production environment",
      "audiences": ["api://AzureADTokenExchange"]
    }'

    echo "AZURE_CLIENT_ID=$AZURE_CLIENT_ID"
    echo "AZURE_TENANT_ID=$AZURE_TENANT_ID"
    echo "AZURE_SUBSCRIPTION_ID=$AZURE_SUBSCRIPTION_ID"