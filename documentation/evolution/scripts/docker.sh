#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/params.sh"

PROJECT_ROOT="$(cd "${SCRIPT_DIR}/../../.." && pwd)"
cd "$PROJECT_ROOT"

docker pull python:3-slim
docker build --network host -t "$CONTAINER:$CURRENT_VERSION" .