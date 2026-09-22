# Remote state in Azure Storage, created by terraform/bootstrap.
# Values below are placeholders - the real storage account/container/key are
# supplied at `terraform init` time via -backend-config, so no account name
# (which varies per user) needs to be hardcoded or committed here:
#
#   terraform init \
#     -backend-config="resource_group_name=rg-aks-platform-tfstate" \
#     -backend-config="storage_account_name=<your-globally-unique-name>" \
#     -backend-config="container_name=tfstate" \
#     -backend-config="key=prod.terraform.tfstate"
#
# State locking is automatic: the azurerm backend takes a blob lease for the
# duration of each operation, so concurrent applies against the same key are
# rejected rather than corrupting state.
terraform {
  backend "azurerm" {}
}
