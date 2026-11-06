# Step 3 - Security

## Disclaimer

This step includes hardening of the repository.
For documentation and demonstraition reason, the repo starts step 3 without apply security patches to the repository.

## Trivy

### Summury after first run

```bash
# terraform
┌─────────┬───────────┬───────────────────┐
│ Target  │   Type    │ Misconfigurations │
├─────────┼───────────┼───────────────────┤
│ .       │ terraform │         0         │
├─────────┼───────────┼───────────────────┤
│ main.tf │ terraform │        15         │
└─────────┴───────────┴───────────────────┘
```

```bash
# Docker image
learningsteps:v0.1.0 (debian 13.7)
==================================
Total: 186 (UNKNOWN: 0, LOW: 62, MEDIUM: 75, HIGH: 49, CRITICAL: 0)
```

```bash
# Secrets in files
┌───────────────────────────────┬───────┬─────────┐
│            Target             │ Type  │ Secrets │
├───────────────────────────────┼───────┼─────────┤
│ learningsteps_rust/Cargo.lock │ cargo │    -    │
└───────────────────────────────┴───────┴─────────┘
```
