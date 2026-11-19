# ==============================================================================
# Local Constants (Workload Identity Federation / OIDC)
# ==============================================================================
# Reference constants for GitHub Actions OpenID Connect (OIDC) federation with
# Microsoft Entra ID, avoiding long-lived Azure client secrets in CI/CD.

locals {
  default_audience_name = "api://AzureADTokenExchange"
  github_issuer_url     = "https://token.actions.githubusercontent.com"
}
