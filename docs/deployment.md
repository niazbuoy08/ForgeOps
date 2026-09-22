# Deployment Guide

This walks through standing up the entire platform from nothing. It assumes
an Azure subscription you can create resources in, and the Azure CLI, kubectl,
Helm, and Terraform installed locally.

## 1. Bootstrap Terraform remote state

```bash
az login
cp terraform/bootstrap/terraform.tfvars.example terraform/bootstrap/terraform.tfvars
# edit storage_account_name to something globally unique
./scripts/bootstrap-backend.sh
```

Note the `resource_group_name` and `storage_account_name` from the output -
every environment needs them.

## 2. Provision infrastructure (dev)

```bash
cd terraform/environments/dev
cp terraform.tfvars.example terraform.tfvars
# edit acr_name and key_vault_name to globally-unique values

export TFSTATE_RESOURCE_GROUP=rg-aks-platform-tfstate
export TFSTATE_STORAGE_ACCOUNT=<your-bootstrap-storage-account>
cd ../../..
./scripts/deploy-infra.sh dev apply
```

This creates: resource group, hub + spoke VNets (peered), AKS cluster
(workload identity + OIDC issuer enabled, Azure Key Vault CSI add-on
enabled), ACR (with `AcrPull` granted to the AKS kubelet identity), Key
Vault (with a Terraform-generated database password), and the three managed
identities described in [architecture.md](architecture.md).

Repeat for `staging`/`prod` only if you actually want dedicated clusters for
them - see [Cost considerations](../README.md#cost-considerations).

## 3. Connect kubectl

```bash
./scripts/get-aks-credentials.sh dev
```

## 4. Install cluster add-ons

```bash
./scripts/install-nginx-ingress.sh
# Optional - only useful once you have a real domain (see step 7):
./scripts/install-cert-manager.sh you@example.com
```

## 5. Install Argo CD and bootstrap GitOps

```bash
./scripts/install-argocd.sh
```

Then fill in the values Terraform generated into the values files Argo CD
reads (these are placeholders in Git on purpose - see
[security.md](security.md)):

```bash
cd terraform/environments/dev
terraform output workload_identity_client_id
terraform output key_vault_name
```

Edit `kubernetes/values/dev/backend.yaml` and `postgres.yaml`:
- `secretsStoreCsi.keyvaultName` -> the Key Vault name
- `secretsStoreCsi.tenantId` -> your Azure AD tenant ID (`az account show --query tenantId -o tsv`)
- `secretsStoreCsi.userAssignedIdentityID` -> the workload identity's **client ID**
- `serviceAccount.annotations["azure.workload.identity/client-id"]` (backend only) -> the same client ID

And in `kubernetes/values/dev/backend.yaml`/`frontend.yaml`, set
`image.repository` to `<your-acr-name>.azurecr.io/aks-platform-backend` (or
`-frontend`) and `image.tag` to any tag already pushed (see step 6) - or
just push once and let `docker-build-push.yml` fill these in for you going
forward.

Commit and push. Argo CD (auto-sync on dev) picks up the change within its
poll interval (default 3 minutes; force it sooner with `argocd app sync
dev-backend`).

## 6. Build and push the application images

Locally, without CI:

```bash
az acr build --registry <your-acr-name> --image aks-platform-backend:manual-001 src/backend
az acr build --registry <your-acr-name> --image aks-platform-frontend:manual-001 src/frontend
```

Or push to `main` with changes under `src/backend/` or `src/frontend/` and
let `.github/workflows/docker-build-push.yml` do it (see
[GitHub configuration](#github-actions-configuration) below for the OIDC
setup it needs).

## 7. Ingress and TLS

```bash
kubectl -n ingress-nginx get svc ingress-nginx-controller
```

Point a DNS A record you control at the `EXTERNAL-IP` shown. Without a real
domain, the ingress still works over plain HTTP at that IP
(`http://<external-ip>/`) - **do not** enable `tls.enabled` in
`kubernetes/values/<env>/ingress.yaml` without a real hostname pointed at
that IP; cert-manager's HTTP-01 challenge will simply fail otherwise. Once
DNS is in place:

```yaml
# kubernetes/values/dev/ingress.yaml
host: "dev.yourdomain.com"
tls:
  enabled: true
  clusterIssuer: letsencrypt-staging   # switch to letsencrypt-prod once verified
```

## GitHub Actions configuration

The workflows authenticate to Azure via OIDC federation - no client secret
is stored in GitHub. Create the federation once:

```bash
az ad app create --display-name aks-gitops-platform-ci
APP_ID=$(az ad app list --display-name aks-gitops-platform-ci --query "[0].appId" -o tsv)
az ad sp create --id "$APP_ID"

az ad app federated-credential create --id "$APP_ID" --parameters '{
  "name": "github-main",
  "issuer": "https://token.actions.githubusercontent.com",
  "subject": "repo:<your-org>/<your-repo>:ref:refs/heads/main",
  "audiences": ["api://AzureADTokenExchange"]
}'

az role assignment create --assignee "$APP_ID" --role Contributor \
  --scope "/subscriptions/<subscription-id>/resourceGroups/rg-aks-platform-dev"
az role assignment create --assignee "$APP_ID" --role AcrPush \
  --scope "/subscriptions/<subscription-id>/resourceGroups/rg-aks-platform-dev/providers/Microsoft.ContainerRegistry/registries/<acr-name>"
```

Then set repository **variables** (Settings -> Secrets and variables ->
Actions -> Variables, not Secrets - these aren't secret):
`AZURE_CLIENT_ID`, `AZURE_TENANT_ID`, `AZURE_SUBSCRIPTION_ID`, `ACR_NAME`,
`TFSTATE_RESOURCE_GROUP`, `TFSTATE_STORAGE_ACCOUNT`.

## Local development (no Azure/AKS required)

```bash
# Postgres for local dev only - never use this container in a cluster
docker run -d --name aks-platform-postgres -e POSTGRES_USER=postgres \
  -e POSTGRES_PASSWORD=postgres -e POSTGRES_DB=appdb -p 5432:5432 postgres:16-alpine

cd src/backend
cp .env.example .env
pip install -r requirements-dev.txt
uvicorn app.main:app --reload

# separate shell
cd src/frontend
cp .env.example .env
npm install
npm run dev   # http://localhost:5173, proxies /api to :8000
```

## Testing

```bash
cd src/backend && pytest -v
cd src/frontend && npm run test
./scripts/validate-all.sh   # everything this repo can validate without live Azure infra
```

## Cleanup

```bash
./scripts/deploy-infra.sh dev destroy   # or: cd terraform/environments/dev && terraform destroy -var-file=terraform.tfvars
# then, if you no longer need remote state either:
cd terraform/bootstrap && terraform destroy
```

`terraform destroy` does not remove the ACR/Key Vault's soft-deleted copies
automatically in all cases - check `az acr list -o table` and `az keyvault
list-deleted -o table` afterward if you want a truly clean subscription.
