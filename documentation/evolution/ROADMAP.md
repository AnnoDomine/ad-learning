# Roadmap to transform from manuell deployment to automated

## Steps

1. **Docker:** Containerize the application, incl. First deployment on ACR (manuell)
2. **IaC:** VNET, AKS, AzureDB (PSQL)
3. **Security:** Scanna and IaC analysis
4. **CI/CD:** Define pipeline
5. **ubernetes:** Orchest all iwth Kubernetes
6. **Monitoring:** Metric and Dashboard

## Documentation

Every single step have to be well documented to summurize at the end based on the success criteria from the [Project Description](../02_learningsteps_evolution.md).

## Differents

Beside the project description, there are diffents in the final reaching out as final project summary.

- **CI/CD:**
  - They will not run `every push`.
  - They will run on push to and pull-request to main for lint/format/test/security-checks.
  - Build & Deployment to Azure will run on tag.
  - All actions can be manuell triggered on main.
  - Additional we create a workflow to trigger new tag called `tag.yml`.
  - Additional there is a workflow to generate the environment if not exists `init_az.yml` which can be manuel triggerd by the `maintainer` only.
- **Methology:**
  - The folder and file structure will be different to the project description.
  - Instead of have all `automatition` folders and files like `infra-terraform` or `Dockerfile` inside the `learningsteps` folder, these will placed inside `workspace-root` folder.

### `tag.xml`

```yaml
name: Release Tagging Pipeline

on:
  workflow_dispatch:
    inputs:
      version:
        description: 'Version string for tag (e.g. 0.1.0 -> creates v0.1.0)'
        required: true
        type: string

permissions:
  contents: write

jobs:
  tag:
    name: Create & Push Git Tag
    runs-on: ubuntu-latest
    if: github.ref == 'refs/heads/main'
    steps:
      - name: Checkout repository
        uses: actions/checkout@3d3c42e5aac5ba805825da76410c181273ba90b1 # v7.0.1
        with:
          fetch-depth: 0
          token: ${{ secrets.GITHUB_TOKEN }}

      - name: Configure Git Author
        run: |
          git config user.name "${{ github.repository_owner }}"
          git config user.email "${{ github.repository_owner_id }}+${{ github.repository_owner }}@users.noreply.github.com"

      - name: Create and Push Tag
        run: |
          TAG_NAME="v${{ inputs.version }}"
          echo "Checking if tag $TAG_NAME already exists..."
          if git rev-parse "$TAG_NAME" >/dev/null 2>&1; then
            echo "Error: Tag $TAG_NAME already exists!" >&2
            exit 1
          fi

          echo "Creating tag $TAG_NAME..."
          git tag -a "$TAG_NAME" -m "Release $TAG_NAME"
          git push origin "$TAG_NAME"

```

### `init_az.yml`

```yaml
name: Initialize Azure Environment

on:
  workflow_dispatch:
    inputs:
      version:
        description: 'Version string for tag (e.g. 0.1.0 -> creates v0.1.0)'
        required: true
        type: string

permissions:
  contents: write

env:
  AZ_API_KEY: ${{ secret.AZ_API_KEY }}
  POSTGRES_USER: ${{ secret.POSTGRES_USER }}
  POSTGRES_PASSWORD: ${{ secret.POSTGRES_PASSWORD }}
  POSTGRES_DB: ${{ secret.POSTGRES_DB }}
  ALERT_EMAIL: "${{ github.repository_owner_id }}+${{ github.repository_owner }}@users.noreply.github.com"

jobs:
  az:
    name: Initialize Azure
    runs-on: ubuntu-latest
    if: github.ref == 'refs/heads/main'
    steps:
      - name: Checkout repository
        uses: actions/checkout@3d3c42e5aac5ba805825da76410c181273ba90b1 # v7.0.1
        with:
          fetch-depth: 0
          token: ${{ secrets.GITHUB_TOKEN }}
      - name: Install az-cli
      ## ...

```

### Folder and File Structure

```bash
|- .git/
|- learningsteps/
|     |- app/
|     |     |...
|     |
|     |- README.md
|     |...
|- infra-terraform/
|     |...
|- k8s-manifests/
|     |...
|- .github/
|     |- workflows/
|     |     |...
|     |...
|- documentation/
|     |- scripts/
|     |     |...
|     |- evolution/
|     |     |
|     |     |- README.md
|     |     |...
|     |
|     |- ORIGIN_SUMMARY.md
|     |- TECHNICAL_WRITEUP.md
|     |- EVOLUTION_SUMMARY.md
|     |...
|
|- Dockerfile
|- .gitignore
|- README.md
|- AGENTS.md
|- 01_learningsteps_origin.md
|- 02_learningsteps_evolution.md
|...
```
