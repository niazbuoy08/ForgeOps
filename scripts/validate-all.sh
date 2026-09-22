#!/usr/bin/env bash
# Runs every local validation check this project supports, without
# requiring Azure credentials or a live cluster. See docs/deployment.md for
# what still requires real infrastructure.
set -uo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
FAILURES=0

section() { echo; echo "=== $1 ==="; }
check() { "$@" || FAILURES=$((FAILURES + 1)); }

section "Terraform fmt"
check terraform fmt -check -recursive "${REPO_ROOT}/terraform"

for stack in bootstrap environments/dev environments/staging environments/prod; do
  section "Terraform validate: ${stack}"
  ( cd "${REPO_ROOT}/terraform/${stack}" && terraform init -backend=false -input=false >/dev/null && terraform validate ) || FAILURES=$((FAILURES + 1))
done

section "Helm lint"
for chart in backend frontend postgres ingress; do
  check helm lint "${REPO_ROOT}/kubernetes/helm/${chart}"
done

section "Helm template (dev values)"
for chart in backend frontend postgres ingress; do
  check helm template "${REPO_ROOT}/kubernetes/helm/${chart}" -f "${REPO_ROOT}/kubernetes/values/dev/${chart}.yaml" >/dev/null
done

section "Backend tests"
( cd "${REPO_ROOT}/src/backend" && pip install -q -r requirements-dev.txt && ruff check . && pytest -q ) || FAILURES=$((FAILURES + 1))

section "Frontend tests"
( cd "${REPO_ROOT}/src/frontend" && npm install --silent && npm run lint && npm run test && npm run build ) || FAILURES=$((FAILURES + 1))

section "Docker build validation"
check docker build -t validate-backend:local "${REPO_ROOT}/src/backend"
check docker build -t validate-frontend:local "${REPO_ROOT}/src/frontend"

section "Secret scan (gitleaks, if installed)"
if command -v gitleaks >/dev/null; then
  check gitleaks detect --source "${REPO_ROOT}" --no-git
else
  echo "gitleaks not installed - skipped"
fi

echo
if [ "$FAILURES" -eq 0 ]; then
  echo "All checks passed."
else
  echo "${FAILURES} check(s) failed."
  exit 1
fi
