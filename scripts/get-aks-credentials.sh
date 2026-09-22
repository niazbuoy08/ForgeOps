#!/usr/bin/env bash
# Fetches kubectl credentials for an environment's AKS cluster using the
# outputs Terraform already computed - avoids hand-typing resource names.
set -euo pipefail

ENVIRONMENT="${1:?Usage: get-aks-credentials.sh <dev|staging|prod>}"

cd "$(dirname "$0")/../terraform/environments/${ENVIRONMENT}"

RESOURCE_GROUP=$(terraform output -raw resource_group_name)
CLUSTER_NAME=$(terraform output -raw aks_cluster_name)

az aks get-credentials \
  --resource-group "$RESOURCE_GROUP" \
  --name "$CLUSTER_NAME" \
  --overwrite-existing

kubectl get nodes
