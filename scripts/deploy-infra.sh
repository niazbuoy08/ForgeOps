#!/usr/bin/env bash
# Runs terraform init/plan/apply for one environment against the remote
# state backend created by bootstrap-backend.sh.
#
# Usage: ./scripts/deploy-infra.sh dev [plan|apply]
set -euo pipefail

ENVIRONMENT="${1:?Usage: deploy-infra.sh <dev|staging|prod> [plan|apply]}"
ACTION="${2:-plan}"

: "${TFSTATE_RESOURCE_GROUP:?Set TFSTATE_RESOURCE_GROUP (from bootstrap output)}"
: "${TFSTATE_STORAGE_ACCOUNT:?Set TFSTATE_STORAGE_ACCOUNT (from bootstrap output)}"

cd "$(dirname "$0")/../terraform/environments/${ENVIRONMENT}"

if [ ! -f terraform.tfvars ]; then
  echo "Create terraform.tfvars from terraform.tfvars.example first." >&2
  exit 1
fi

terraform init \
  -backend-config="resource_group_name=${TFSTATE_RESOURCE_GROUP}" \
  -backend-config="storage_account_name=${TFSTATE_STORAGE_ACCOUNT}" \
  -backend-config="container_name=tfstate" \
  -backend-config="key=${ENVIRONMENT}.terraform.tfstate"

terraform fmt -check
terraform validate

case "$ACTION" in
  plan)
    terraform plan -var-file=terraform.tfvars
    ;;
  apply)
    terraform apply -var-file=terraform.tfvars
    ;;
  destroy)
    terraform destroy -var-file=terraform.tfvars
    ;;
  *)
    echo "Unknown action: $ACTION (expected plan, apply, or destroy)" >&2
    exit 1
    ;;
esac
