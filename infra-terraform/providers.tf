# ==============================================================================
# Terraform Provider & Remote State Configuration
# ==============================================================================
# Pins exact compatible provider versions for reproducible IaC runs across local
# environments and GitHub Actions. The Azure Storage backend is intentionally
# left empty so environment-specific state details and OIDC authentication
# (`use_azuread_auth=true`) are injected dynamically via `-backend-config`.

terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 5.13.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.9.1"
    }
  }

  # Remote state parameters are supplied dynamically during `terraform init`
  # in `.github/workflows/deploy.yml` and `.github/workflows/destroy.yml`.
  backend "azurerm" {}

  required_version = ">= 1.1.0"
}

provider "azurerm" {
  features {
    key_vault {
      # Allow automated destroy/recreate cycles without soft-delete name collisions
      purge_soft_deleted_keys_on_destroy = true
      recover_soft_deleted_keys          = true
    }
    resource_group {
      # Required so `terraform destroy` can clean up the Resource Group even if
      # AKS or Azure creates residual sub-resources during teardown
      prevent_deletion_if_contains_resources = false
    }
  }
}
