#!/usr/bin/env bash
# ==============================================================================
# Local Security Audit Helper – Generate Trivy Scan Logs
# ==============================================================================
# Executes local Trivy scans for Terraform IaC (`infra-terraform/`), the
# container image (`learningsteps:v0.1.0`), and filesystem secrets, saving raw
# reports under `output/trivy/` and archiving them into `documentation/evolution/`.

set -euo pipefail

echo "|-------------------------------------------------------------|"
echo "|     Generating TRIVY logs into 'output/trivy/<type>.log'    |"
echo "|-------------------------------------------------------------|"
echo "|                                                             |"
echo "| - Check if 'trivy' is installed:                            |"
echo "|      > which trivy                                          |"

# Abort with installation instructions if Trivy CLI is missing
if ! command -v trivy >/dev/null 2>&1; then
  echo "|                                                             |"
  echo "| ERROR: 'trivy' not installed, please visit:                 |"
  echo "| https://trivy.dev/docs/latest/getting-started/installation/ |"
  echo "|                                                             |"
  echo "|-------------------------------------------------------------|"
  echo "|------------------------  EXIT  -----------------------------|"
  echo "|-------------------------------------------------------------|"
  exit 1
fi

echo "| 'trivy is installed - Running scans                         |"
echo "|                                                             |"
echo "|-------------------------------------------------------------|"
echo "|                                                             |"
echo "| - Check if output folder exists and create if not:          |"

# Ensure output directories exist before piping with `tee`
mkdir -p ./output
mkdir -p ./output/trivy

echo "| - Folders exist.                                            |"
echo "| - Starting 'TERRAFORM' scans                                |"

trivy config infra-terraform/ | tee output/trivy/terraform.log

echo "|                                                             |"
echo "| - Starting 'Docker Image' scans                             |"

trivy image learningsteps:v0.1.0 | tee output/trivy/image.log

echo "|                                                             |"
echo "| - Starting 'Secrets in files' scans                         |"

trivy fs --scanners secret . | tee output/trivy/fs.log

echo "|                                                             |"
echo "|-------------------------------------------------------------|"
echo "|                                                             |"
echo "| Copy output to 'evolution documentation'                    |"

cp -r ./output ./documentation/evolution/

echo "|                                                             |"
echo "|-------------------------------------------------------------|"
echo "|-----------------  Have a N.I.C.E day  ----------------------|"
echo "|-------------------------------------------------------------|"
