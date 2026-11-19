#!/usr/bin/env bash
# ==============================================================================
# Legacy Step-1 Script – Local Docker Image Build
# ==============================================================================
# Part of the initial Step-1 manual bootstrap (superseded in Steps 2-5 by
# `.github/workflows/trivy.yml` and `.github/workflows/deploy.yml`).

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/params.sh"

# Resolve repository root so Docker finds the root `Dockerfile` and `learningsteps/`
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/../../.." && pwd)"
cd "$PROJECT_ROOT"

docker pull python:3-slim
docker build --network host -t "$CONTAINER:$CURRENT_VERSION" .
