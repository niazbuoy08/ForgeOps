#!/usr/bin/env bash
# Rolls an Argo CD Application back to a previous, already-synced revision.
# This uses Argo CD's own history (equivalent to `helm rollback`), not a new
# Git commit, so it is immediate.
#
# Usage:
#   ./scripts/rollback.sh dev-backend           # rollback to the previous deployed revision
#   ./scripts/rollback.sh dev-backend list       # list revision history first
set -euo pipefail

APP="${1:?Usage: rollback.sh <argocd-app-name> [list]}"
MODE="${2:-rollback}"

if [ "$MODE" = "list" ]; then
  argocd app history "$APP"
  exit 0
fi

echo "Current history for $APP:"
argocd app history "$APP"

read -rp "Enter the ID to roll back to (leftmost column above): " REVISION_ID
argocd app rollback "$APP" "$REVISION_ID"
argocd app wait "$APP" --health
