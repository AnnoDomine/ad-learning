# ==============================================================================
# LearningSteps FastAPI Application – Hardened Container Image
# ==============================================================================
# Builds a minimal, non-root production image on Python 3.13-slim with patched
# OS packages and zero runtime package managers (pip/setuptools/ensurepip).

# Pin minor Python version to match CI lint/test environment (`3.13`)
FROM python:3.13-slim

# Patch Debian base OS vulnerabilities (e.g., zlib1g CVE-2026-85091) and purge apt cache
RUN apt-get update && apt-get upgrade -y --no-install-recommends && rm -rf /var/lib/apt/lists/*

WORKDIR /api

# Create dedicated unprivileged user (UID 1000, matched by K8s `runAsUser: 1000`)
RUN [ "useradd", "apiuser" ]

# Copy dependency manifest separately to leverage Docker layer caching
COPY learningsteps/api/requirements.txt .

# Enforce patched transitive library minimums (Trivy HIGH CVEs on msgpack/urllib3)
RUN [ "pip", "install", "--no-cache-dir", "--upgrade", "-r", "requirements.txt", "msgpack>=1.2.3", "urllib3>=2.8.0" ]

# Remove package manager and bundled wheels (`pip`, `setuptools`, `ensurepip`) to eliminate
# vendored CVEs and shrink the runtime attack surface
RUN pip uninstall -y pip setuptools && rm -rf /usr/local/lib/python*/ensurepip

# Copy FastAPI application source code
COPY learningsteps/api/ .

# Drop root privileges prior to starting the ASGI server
USER apiuser

CMD ["uvicorn", "main:app", "--host", "0.0.0.0", "--port", "8000"]

EXPOSE 8000
