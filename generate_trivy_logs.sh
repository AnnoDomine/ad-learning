#!/usr/bin/env bash
set -euo pipefail


echo "|-------------------------------------------------------------|"
echo "|     Generating TRIVY logs into 'output/trivy/<type>.log'    |"
echo "|-------------------------------------------------------------|"
echo "|                                                             |"
echo "| - Check if 'trivy' is installed:                            |"
echo "|      > which trivy                                          |"

# If trivy not installed, exit code 1 with info please visit [https://trivy.dev/docs/latest/getting-started/installation/]

 if ! command -v trivy >/dev/null 2>&1; then
    echo "|                                                             |"
    echo "| ERROR: 'trivy' not installed, please visite:                |"
    echo "| https://trivy.dev/docs/latest/getting-started/installation/ |"
    echo "|                                                             |"
    echo "|-------------------------------------------------------------|"
    echo "|------------------------  EXIT  -----------------------------|"
    echo "|-------------------------------------------------------------|"
    exit 1
fi

echo "| 'trivis installed - Running scans                           |"
echo "|                                                             |"
echo "|-------------------------------------------------------------|"
echo "|                                                             |"
echo "| - Check if output folder exist and create if not:           |"

# Generate folder
mkdir -p ./output
mkdir -p ./output/trivy

echo "| - Folders exists.                                           |"
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