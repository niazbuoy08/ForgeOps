#!/usr/bin/env bash
# One-time: creates the resource group + storage account that holds every
# environment's Terraform remote state. Run this once per Azure subscription
# before `terraform init` in any terraform/environments/<env> directory.
set -euo pipefail

cd "$(dirname "$0")/../terraform/bootstrap"

if [ ! -f terraform.tfvars ]; then
  echo "Create terraform/bootstrap/terraform.tfvars from terraform.tfvars.example first (storage_account_name must be globally unique)." >&2
  exit 1
fi

terraform init
terraform apply

echo
echo "Bootstrap complete. Use these values with 'terraform init -backend-config=...' in each environment:"
terraform output
