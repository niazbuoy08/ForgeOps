# Troubleshooting

## Terraform

**`Error: A resource with the ID ... already exists`**
Someone (or a previous partial apply) already created that resource outside
Terraform's current state. Either `terraform import` it or delete it in the
Azure Portal/CLI and re-apply.

**`Error: building account: unable to configure ResourceManagerAccount`**
Run `az login` again, or check `az account show` points at the subscription
your `terraform.tfvars`/backend config expects.

**`storage account name already taken`**
Storage account, ACR, and Key Vault names are globally unique across all of
Azure, not just your subscription. Pick a more specific name (add your
initials or a random suffix).

**Federated credential / workload identity apply fails with an empty
`oidc_issuer_url`**
The AKS cluster must exist first. On the very first `apply` for a new
environment, Terraform creates the cluster and the federated credentials in
the same run (the dependency graph handles ordering) - if you see this error,
you most likely ran `apply` with `-target` on a subset of resources. Re-run
a full `terraform apply` instead.

## AKS / kubectl

**`kubectl` times out or shows `Unable to connect to the server`**
Re-run `./scripts/get-aks-credentials.sh <env>` - AKS admin credentials can
rotate, and merged kubeconfigs occasionally point at a stale context. Check
`kubectl config current-context`.

**Pods stuck in `Pending`**
```bash
kubectl -n dev describe pod <pod>
```
Usually either insufficient node capacity (check `node_count_max` in
`terraform.tfvars` and the cluster autoscaler's current node count with
`kubectl get nodes`) or a `PersistentVolumeClaim` that can't bind (see
below).

**Postgres PVC stuck `Pending`**
```bash
kubectl -n dev get pvc
kubectl -n dev describe pvc data-postgres-0
```
Confirm the `storageClassName` in `kubernetes/values/<env>/postgres.yaml`
matches a StorageClass that actually exists in the cluster
(`kubectl get storageclass`) - AKS ships `managed-csi` by default;
`managed-csi-premium` (used in prod) requires Premium_LRS-capable VM sizes.

## Secrets Store CSI Driver

**Pod stuck in `ContainerCreating` with a `FailedMount` event mentioning
`secrets-store.csi.k8s.io`**
```bash
kubectl -n dev describe pod <pod>
kubectl -n dev get secretproviderclass
```
Almost always one of:
1. `secretsStoreCsi.keyvaultName`/`tenantId`/`userAssignedIdentityID` in the
   values file is still the empty-string placeholder - fill them in from
   `terraform output` (see [deployment.md](deployment.md) step 5).
2. The pod's `ServiceAccount` is missing the
   `azure.workload.identity/client-id` annotation, or the pod template is
   missing the `azure.workload.identity/use: "true"` label (the backend
   chart sets this automatically when `azureWorkloadIdentity.enabled: true`
   - confirm that's set in the values file).
3. The federated credential's `subject` doesn't match
   `system:serviceaccount:<namespace>:<serviceaccountname>` exactly - check
   `terraform output` in the environment that owns the identity, or
   `az identity federated-credential list`.

**Secret exists as a file under `/mnt/secrets-store` but env vars are
empty**
The `secretObjects` sync (which mirrors the CSI-mounted secret into a native
Kubernetes `Secret`, consumed via `envFrom`) can take a few seconds after
the pod starts. If it never appears, check
`kubectl -n dev describe secretproviderclass backend-secrets` for sync
errors, and confirm the Key Vault secret names match `objectName` exactly
(`db-username`, `db-password`, `db-host`, `db-name`).

## Argo CD

**Application stuck `OutOfSync` with `automated` sync policy set**
Check `argocd app get <app>` for the actual diff. A common cause is a Helm
`valueFiles` path typo - Argo CD's relative path (`../../values/<env>/...`)
is resolved from the chart directory, not the repo root.

**`argocd app sync` fails with `permission denied` on the AppProject**
The `AppProject`'s `destinations`/`namespaceResourceWhitelist` doesn't cover
what you're trying to deploy. Check
`argocd/projects/aks-platform-project.yaml`.

**Argo CD never picks up a commit**
Confirm the app-of-apps roots were actually applied
(`kubectl -n argocd get application`) - `argocd/bootstrap/*.yaml` is not
auto-applied by anything; it's the one manual `kubectl apply` step in
[gitops.md](gitops.md).

## CI/CD

**`docker-build-push.yml` fails at `az acr build` with an authorization
error**
The federated credential's `subject` must match the branch that triggered
the workflow exactly (`repo:<org>/<repo>:ref:refs/heads/main`). Re-check the
`az ad app federated-credential create` command in
[deployment.md](deployment.md).

**`docker-build-push.yml`'s commit-back step fails with a push rejection**
Another workflow run (or a human) pushed to `main` in between the checkout
and the push. The workflow already does `git pull --rebase` before pushing;
if it still fails, just re-run the job.

## Ingress / TLS

**`cert-manager` Certificate stuck `False` / `Pending`**
```bash
kubectl -n dev describe certificate
kubectl -n dev describe certificaterequest
kubectl -n dev describe order
kubectl -n dev describe challenge
```
The overwhelming majority of the time this is DNS: the HTTP-01 challenge
needs the hostname in `kubernetes/values/<env>/ingress.yaml` to already
resolve to the ingress controller's public IP *before* you enable
`tls.enabled`.

**503 from the ingress**
```bash
kubectl -n ingress-nginx logs deploy/ingress-nginx-controller
kubectl -n dev get endpoints backend frontend
```
An empty `Endpoints` object means the Service's selector doesn't match any
`Ready` pod - check the deployment's `readinessProbe` is actually passing.
