# Production Style AKS Platform with GitOps on Azure

A portfolio-quality reference implementation of a three-tier application
(React + FastAPI + PostgreSQL) deployed to Azure Kubernetes Service, with
infrastructure defined in Terraform and application delivery driven entirely
by GitOps through Argo CD.

This is not a toy repo of disconnected snippets: every Terraform module,
Helm chart, and Argo CD Application here is meant to actually apply and
deploy, wired together end to end - Key Vault secrets flow into pods through
Workload Identity and the Secrets Store CSI Driver, images are built and
tagged with immutable git SHAs by GitHub Actions, and Argo CD is the only
thing that ever touches the Kubernetes API in a real deployment.

## Table of contents

- [Project overview](#project-overview)
- [Architecture](#architecture)
- [Technology stack](#technology-stack)
- [Repository structure](#repository-structure)
- [Prerequisites](#prerequisites)
- [Quick start](#quick-start)
- [Azure, Terraform, and remote state setup](#azure-terraform-and-remote-state-setup)
- [AKS, ACR, and Key Vault](#aks-acr-and-key-vault)
- [Secret management](#secret-management)
- [Helm deployment](#helm-deployment)
- [Argo CD deployment and GitOps workflow](#argo-cd-deployment-and-gitops-workflow)
- [Progressive delivery](#progressive-delivery)
- [CI/CD workflow](#cicd-workflow)
- [Supply chain security](#supply-chain-security)
- [Policy as code](#policy-as-code)
- [Observability](#observability)
- [Ingress and TLS](#ingress-and-tls)
- [Local development](#local-development)
- [Testing](#testing)
- [Rollback](#rollback)
- [Troubleshooting](#troubleshooting)
- [Cleanup](#cleanup)
- [Security considerations](#security-considerations)
- [Cost considerations](#cost-considerations)
- [Validation status](#validation-status)

## Project overview

The application is a small "items" CRUD dashboard: a React/Vite/TypeScript
frontend showing live application/backend/database health and a table of
records, backed by a FastAPI REST API, backed by PostgreSQL. It exists to
give the platform something real to deploy - the interesting part of this
repo is everything around it.

## Architecture

See [docs/architecture.md](docs/architecture.md) for the reasoning behind
each decision (hub/spoke networking, per-environment Terraform stacks,
single-cluster multi-namespace demo topology, Workload Identity, GitOps-only
deployment).

![AKS GitOps Platform architecture diagram: developer pushes to GitHub, GitHub Actions builds/signs images into ACR and commits image tags to Git, Argo CD reconciles the AKS cluster (ingress, frontend, backend canary, postgres, Kyverno, monitoring) from Git, Key Vault feeds secrets via Workload Identity, and the internet reaches the cluster through NGINX ingress](docs/images/architecture-diagram.png)

All of this runs inside an AKS cluster in a spoke VNet, peered to a hub VNet
reserved for shared connectivity infrastructure.

## Technology stack

| Layer | Technology |
|---|---|
| Frontend | React 18, Vite, TypeScript |
| Backend | Python 3.12, FastAPI, SQLAlchemy 2.0 |
| Database | PostgreSQL 16 |
| Infrastructure | Terraform (azurerm ~> 4.0) |
| Container platform | Azure Kubernetes Service (Azure CNI Overlay, Workload Identity) |
| Registry | Azure Container Registry |
| Secrets | Azure Key Vault + Secrets Store CSI Driver |
| Packaging | Helm 3 |
| GitOps | Argo CD |
| Ingress | NGINX Ingress Controller, cert-manager |
| CI/CD | GitHub Actions (OIDC federation to Azure, no stored credentials) |
| Progressive delivery | Argo Rollouts (canary, Prometheus-gated analysis) |
| Supply chain security | cosign (keyless signing), syft (SPDX SBOMs) |
| Policy as code | Kyverno (admission control, GitOps-managed policies) |
| Observability | kube-prometheus-stack (Prometheus, Grafana, Alertmanager) |
| Dependency automation | Dependabot (Actions, Docker, pip, npm, Terraform) |

## Repository structure

```
terraform/
  modules/{resource_group,network,aks,acr,key_vault,storage,identity}/
  environments/{dev,staging,prod}/     # independent Terraform stacks
  bootstrap/                            # one-time remote state storage account
kubernetes/
  helm/{backend,frontend,postgres,ingress}/   # environment-agnostic charts
  values/{dev,staging,prod}/                  # per-environment overrides
  values/monitoring/                          # kube-prometheus-stack values
  namespaces/                                  # dev/staging/prod Namespace manifests
  policies/                                    # Kyverno ClusterPolicy manifests
  monitoring/dashboards/                       # Grafana dashboard ConfigMaps
argocd/
  projects/            # AppProject
  bootstrap/            # app-of-apps roots: one per environment, plus platform
  applications/{dev,staging,prod,platform}/    # one Application per component
src/
  frontend/   # React + Vite + TypeScript
  backend/    # FastAPI + SQLAlchemy
.github/
  workflows/   # Terraform CI, backend/frontend CI, image build+push (+sign/SBOM), promote, security scan
  dependabot.yml
scripts/    # bootstrap, deploy, credential, install (ingress/cert-manager/Argo CD/monitoring/rollouts/Kyverno), rollback, and validation helpers
docs/       # architecture, deployment, security, gitops, observability, troubleshooting
```

## Prerequisites

- Azure subscription with `Contributor` (infra) and `User Access
  Administrator` or equivalent (role assignments) access
- [Azure CLI](https://learn.microsoft.com/cli/azure/install-azure-cli) >= 2.60
- [Terraform](https://developer.hashicorp.com/terraform/install) >= 1.7
- [Helm](https://helm.sh/docs/intro/install/) >= 3.14
- `kubectl` >= 1.29
- [Argo CD CLI](https://argo-cd.readthedocs.io/en/stable/cli_installation/) (for rollback/sync commands)
- Node.js 20+ and Python 3.12+ (local development only)
- Docker (local image builds only - CI builds via `az acr build`, no local Docker required there)
- Optional, for the additions below: [cosign](https://docs.sigstore.dev/cosign/installation/)
  (verify image signatures locally), [`kubectl argo rollouts` plugin](https://argo-rollouts.readthedocs.io/en/stable/installation/#kubectl-plugin-installation)
  (watch canaries)

## Quick start

```bash
az login
git clone <this-repo> && cd aks-gitops-platform  # or your repo's actual name

# 1. One-time remote state backend
cp terraform/bootstrap/terraform.tfvars.example terraform/bootstrap/terraform.tfvars
# edit storage_account_name to something globally unique
./scripts/bootstrap-backend.sh

# 2. Infrastructure
cd terraform/environments/dev
cp terraform.tfvars.example terraform.tfvars
# edit acr_name and key_vault_name to globally-unique values
cd ../../..
export TFSTATE_RESOURCE_GROUP=rg-aks-platform-tfstate
export TFSTATE_STORAGE_ACCOUNT=<your-bootstrap-storage-account>
./scripts/deploy-infra.sh dev apply

# 3. Cluster access + add-ons
./scripts/get-aks-credentials.sh dev
./scripts/install-nginx-ingress.sh
./scripts/install-argocd.sh
./scripts/install-monitoring.sh       # optional: Prometheus/Grafana/Alertmanager
./scripts/install-argo-rollouts.sh    # optional: canary deployments for the backend
./scripts/install-kyverno.sh          # optional: policy-as-code admission control

# 4. Wire Key Vault values into the Helm values files (see docs/deployment.md step 5),
#    then push - Argo CD (auto-sync on dev) deploys the app.
```

Full walkthrough, including GitHub Actions OIDC setup and TLS: [docs/deployment.md](docs/deployment.md).

## Azure, Terraform, and remote state setup

Each environment (`dev`/`staging`/`prod`) is an independent Terraform root
module under `terraform/environments/`, composing the modules in
`terraform/modules/` into its own resource group, hub+spoke VNet pair, AKS
cluster, ACR, Key Vault, and managed identities. Remote state lives in an
Azure Storage account created once by `terraform/bootstrap/` (a separate,
locally-stated configuration, since there's no backend to store *its* state
in yet - see the comments in `terraform/bootstrap/main.tf`). Locking is
automatic: the `azurerm` backend takes a blob lease per operation, so
concurrent `apply`s against the same state key are rejected outright.

```bash
./scripts/deploy-infra.sh dev plan     # or staging / prod
./scripts/deploy-infra.sh dev apply
```

No `terraform.tfstate`, `.terraform/`, or real `*.tfvars` file is committed
- see `.gitignore`. `terraform fmt` and `terraform validate` run in CI on
every PR touching `terraform/**` ([`.github/workflows/terraform-ci.yml`](.github/workflows/terraform-ci.yml)).

## AKS, ACR, and Key Vault

- **AKS**: Azure CNI Overlay, Azure network policy, Workload Identity +
  OIDC issuer enabled, the AKS-managed Azure Key Vault provider for Secrets
  Store CSI Driver enabled as a cluster add-on, autoscaling node pool in the
  spoke subnet.
- **ACR**: `Standard` SKU, admin account disabled - the AKS kubelet managed
  identity is granted `AcrPull` directly, no shared credentials.
- **Key Vault**: RBAC-authorized (not access policies), holds
  `db-username`/`db-password`/`db-host`/`db-name` secrets. The password is
  generated by Terraform's `random_password` resource - nobody, including
  whoever runs `terraform apply`, needs to invent or type it.

## Secret management

Full detail in [docs/security.md](docs/security.md). In one sentence: the
database password is generated by Terraform, stored only in Key Vault, and
reaches pods at runtime via the Secrets Store CSI Driver authenticating with
a Workload Identity federated credential scoped to that pod's exact
`(namespace, service account)` - it is never a file in this repository.

## Helm deployment

Four charts under `kubernetes/helm/`: `backend`, `frontend`, `postgres`,
`ingress`. Each is environment-agnostic; differences between `dev`,
`staging`, and `prod` live entirely in `kubernetes/values/<env>/*.yaml`
(replica counts, resource requests/limits, autoscaling, CORS origin,
ingress host/TLS). You can deploy any chart standalone with Helm directly
(useful for local iteration):

```bash
helm upgrade --install backend kubernetes/helm/backend \
  -f kubernetes/values/dev/backend.yaml \
  --namespace dev --create-namespace
```

In the real GitOps flow, though, Argo CD runs this - you don't `helm
upgrade` by hand against a real environment.

## Argo CD deployment and GitOps workflow

Full detail, including the sync-policy table and promotion flow, in
[docs/gitops.md](docs/gitops.md). Summary: dev and staging auto-sync with
pruning and self-healing; prod requires an explicit `argocd app sync` after
review, by design - see that doc for the reasoning. Cluster-shared objects
that aren't tied to one environment (currently: Kyverno's policies) flow
through a fourth `platform-apps` root the same way.

## Progressive delivery

The backend deploys as an [Argo Rollouts](https://argo-rollouts.readthedocs.io)
canary (`kubernetes/helm/backend/templates/rollout.yaml`) instead of a plain
`Deployment`: ramps traffic in weighted steps, with an optional
Prometheus-gated `AnalysisTemplate` that auto-aborts the rollout if the 5xx
error rate spikes during the canary pause. Full detail, including how to
watch/promote/abort one: [docs/gitops.md#progressive-delivery](docs/gitops.md#progressive-delivery).

## CI/CD workflow

| Workflow | Trigger | Does |
|---|---|---|
| `terraform-ci.yml` | PR/push touching `terraform/**` | `fmt -check`, `validate` for every stack; `plan` on PRs (if Azure OIDC vars are configured) |
| `backend-ci.yml` | PR/push touching `src/backend/**` | ruff lint, pytest |
| `frontend-ci.yml` | PR/push touching `src/frontend/**` | eslint, vitest, `vite build` |
| `docker-build-push.yml` | push to `main` touching `src/**` | `az acr build` (immutable `<run>-<sha>` tag), cosign-signs + attaches a syft SBOM to each image, commits the new tag into `kubernetes/values/dev/*.yaml` |
| `promote.yml` | manual (`workflow_dispatch`) | opens a PR copying an image tag from one environment's values file to the next |
| `security-scan.yml` | PR/push/weekly | Gitleaks, tfsec, Trivy (SARIF uploaded to code scanning) |
| `dependabot.yml` | weekly | opens PRs for GitHub Actions, Docker base images, pip, npm, and Terraform provider updates |

CI never runs `kubectl apply`/`helm upgrade` against a real cluster - it
only ever changes Git, and Argo CD (already running inside the cluster) is
what applies the change. See [docs/gitops.md](docs/gitops.md).

## Supply chain security

Every image is keyless-signed with cosign (GitHub OIDC -> Sigstore Fulcio,
no stored signing key) and gets a syft-generated SPDX SBOM attached as a
signed attestation, both by immutable digest. Full detail and the
verification command: [docs/security.md#supply-chain-security](docs/security.md#supply-chain-security).

## Policy as code

[Kyverno](https://kyverno.io) enforces resource limits and a no-`:latest`-tag
rule cluster-wide, and audits that backend/frontend images carry a valid
cosign signature from the workflow above. The controller is installed via
script (`scripts/install-kyverno.sh`); the policies themselves are
GitOps-managed. Full detail: [docs/security.md#policy-as-code](docs/security.md#policy-as-code).

## Observability

`scripts/install-monitoring.sh` stands up kube-prometheus-stack
(Prometheus, Grafana, Alertmanager) cluster-wide, scrapes the backend's
`/metrics` and the ingress-nginx controller, and ships alert rules
(backend down, high 5xx rate, high p95 latency) plus a Grafana dashboard.
Full detail, including how to reach Grafana: [docs/observability.md](docs/observability.md).

## Ingress and TLS

NGINX Ingress routes `/` to the frontend and `/api`, `/health` to the
backend. TLS is via cert-manager + a Let's Encrypt `ClusterIssuer`, and it
is **off by default** in `kubernetes/values/dev/ingress.yaml` because a demo
cluster usually has no real domain - enabling it without DNS pointed at the
ingress controller's IP will just leave the `Certificate` stuck `Pending`
forever (a real, honest failure mode, not something this repo papers over).
Once you have a domain, it's a two-line values change - see
[docs/deployment.md](docs/deployment.md#7-ingress-and-tls).

## Local development

```bash
docker run -d --name aks-platform-postgres -e POSTGRES_USER=postgres \
  -e POSTGRES_PASSWORD=postgres -e POSTGRES_DB=appdb -p 5432:5432 postgres:16-alpine

cd src/backend && cp .env.example .env && pip install -r requirements-dev.txt && uvicorn app.main:app --reload
cd src/frontend && cp .env.example .env && npm install && npm run dev
```

Frontend: http://localhost:5173 (proxies `/api` to `:8000`). Backend docs:
http://localhost:8000/docs.

## Testing

```bash
cd src/backend && pytest -v
cd src/frontend && npm run test
./scripts/validate-all.sh   # fmt/validate/lint/test/build across the whole repo, no Azure required
```

## Rollback

```bash
argocd app history dev-backend
argocd app rollback dev-backend <ID>          # immediate, Argo CD-level
# or, to make it stick:
git revert <bad-commit> && git push origin main
```

Full explanation of the two rollback layers: [docs/gitops.md](docs/gitops.md#rollback).

## Troubleshooting

[docs/troubleshooting.md](docs/troubleshooting.md) - Terraform, AKS, the
CSI driver, Argo CD, CI/CD, and ingress/TLS failure modes, each with the
actual command to diagnose it.

## Cleanup

```bash
./scripts/deploy-infra.sh dev destroy
cd terraform/bootstrap && terraform destroy   # only if you're done with the whole project
```

Check `az acr list -o table` / `az keyvault list-deleted -o table`
afterward - soft-deleted Key Vaults in particular can block reusing the same
name.

## Security considerations

Full detail: [docs/security.md](docs/security.md). Highlights: no secrets
in Git, no service principal passwords anywhere (OIDC federation for CI,
Workload Identity for pods), non-root/read-only-root containers with
dropped capabilities, `NetworkPolicy` restricting postgres to backend pods
only, PostgreSQL never has a public IP, immutable image tags, cosign-signed
images with attached SBOMs, and Kyverno admission policies enforcing
resource limits, no `:latest` tags, and signature verification.

## Cost considerations

Running all three Terraform environments (`dev`/`staging`/`prod`) means
three AKS clusters, three ACRs, three Key Vaults - real money. For a
portfolio demo:

- Stand up **only `dev`**. The Argo CD setup already deploys `dev`,
  `staging`, and `prod` **namespaces** onto that one cluster by default
  (see [docs/architecture.md](docs/architecture.md)), which is enough to
  demonstrate environment separation, differing sync policies, and the
  promotion workflow without paying for extra clusters.
- Use `aks_sku_tier = "Free"` and a small `node_vm_size`/`node_count_max`
  in `dev`'s `terraform.tfvars` (already the default).
- `terraform destroy` the environment when you're not actively
  demonstrating it - Key Vault names must be globally unique, but a
  soft-deleted vault can usually be recovered/purged and its name reused
  (`az keyvault list-deleted`).
- Only provision `staging`/`prod` as real, separate clusters if you
  specifically want to demonstrate multi-cluster promotion - it's fully
  wired up to do so, it's just not the cost-optimized default.

## Validation status

See the PR/commit this was built in, or run `./scripts/validate-all.sh`
yourself. As of this build:

**Validated locally** (see command output in that script): `terraform fmt`,
`terraform validate` for all four stacks (bootstrap, dev, staging, prod);
`helm lint` and `helm template` for all four charts against all three
environments' values, including the backend's `Rollout`/`AnalysisTemplate`/
`ServiceMonitor` additions; backend `pytest` (7 tests) and `ruff check`;
frontend `vitest`, `eslint`, and `vite build`; a manual review for hardcoded
secrets (none found - see [docs/security.md](docs/security.md)); the
Kyverno `ClusterPolicy` and Argo CD `Application`/`AppProject` manifests
reviewed by hand against their schemas (YAML-parsed, not cluster-validated).

**Requires a live cluster** (not exercised by this build - see
[observability.md](docs/observability.md) and
[gitops.md#progressive-delivery](docs/gitops.md#progressive-delivery)):
the monitoring stack actually scraping targets and firing alerts; a real
Argo Rollouts canary promotion/abort, including the Prometheus-gated
analysis step; Kyverno admitting/blocking a real Pod against the three
policies; a cosign signature actually verifying against a real signed
image.

**Requires Azure credentials**: `terraform plan`/`apply` against a real
subscription; ACR image builds; Key Vault secret creation; anything under
[docs/deployment.md](docs/deployment.md) steps 1-3.

**Requires GitHub configuration**: the OIDC federated credential + repo
variables described in
[docs/deployment.md](docs/deployment.md#github-actions-configuration) - without
them, `docker-build-push.yml`/`promote.yml`/the plan step of
`terraform-ci.yml` no-op safely rather than failing.

**Requires DNS**: TLS via cert-manager (see
[Ingress and TLS](#ingress-and-tls)) - HTTP-only ingress works with no DNS
at all, against the ingress controller's bare public IP.

**Requires production infrastructure** (i.e. not exercised by this build):
a live multi-day Argo CD self-heal/drift demonstration; an actual `staging`/
`prod` AKS cluster (Terraform for them is real and validated, just not
applied - see [Cost considerations](#cost-considerations)); a real Let's
Encrypt certificate issuance.
