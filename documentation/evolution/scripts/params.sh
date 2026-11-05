export RG="learningsteps-evo-lab-rg"
export REGION="germanywestcentral"
export VNET="learningsteps-evo-vnet"
export ACR="${ACR:-learningstepsevoacr$(openssl rand -hex 4)}"
export CONTAINER="learningsteps"
export CURRENT_VERSION="${CURRENT_VERSION:-v0.1.0}"
export CONTAINER_LINK="$ACR.azurecr.io/${CONTAINER}:$CURRENT_VERSION"

# Repository- und Pfad-Konfiguration für das App-Deployment
export REPO_URL="${REPO_URL:-https://github.com/AnnoDomine/ad-learning.git}"
export REPO_BRANCH="${REPO_BRANCH:-main}"
export REPO_SUBDIR="${REPO_SUBDIR:-learningsteps}"

# Datenbank- & App-Credentials (aus Environment-Variablen / GitHub Secrets)
export POSTGRES_USER="${POSTGRES_USER:-postgres}"
export POSTGRES_PASSWORD="${POSTGRES_PASSWORD:-}"
export POSTGRES_DB="${POSTGRES_DB:-learning_journal}"

# Alerting-Konfiguration (aus Environment-Variablen / GitHub Secrets)
export ALERT_EMAIL="${ALERT_EMAIL:-}"
