# GitOps Workflow

## Structure

```
argocd/
  projects/aks-platform-project.yaml   # AppProject - scopes what Argo CD is allowed to touch
  bootstrap/{dev,staging,prod}-apps.yaml  # app-of-apps roots, one per environment
  applications/{dev,staging,prod}/*.yaml  # one Application per component (backend/frontend/postgres/ingress)
kubernetes/
  helm/{backend,frontend,postgres,ingress}/  # the charts themselves (environment-agnostic)
  values/{dev,staging,prod}/*.yaml           # per-environment overrides
```

Each `Application` points its `source.path` at a chart under
`kubernetes/helm/` and layers a `helm.valueFiles` entry pointing at the
matching file under `kubernetes/values/<env>/`. Applying a new chart version
or values change is exactly a Git commit to one of these files - nothing
else.

## Bootstrapping

Argo CD does not know about any of this until you apply the app-of-apps
roots once, manually:

```bash
kubectl apply -f argocd/projects/aks-platform-project.yaml
kubectl apply -f argocd/bootstrap/
```

From that point on, `dev-apps`/`staging-apps`/`prod-apps` watch their
respective `argocd/applications/<env>/` directory and create/update/delete
the child `Application` objects there automatically (this is the
"app-of-apps" pattern) - adding a new component is just adding a YAML file
to that directory and pushing.

## Sync policy per environment

| Environment | `automated` | `prune` | `selfHeal` | Why |
|---|---|---|---|---|
| dev | yes | yes | yes | Fully automatic GitOps: any merge to `main` touching `dev` values deploys immediately. This is what `docker-build-push.yml` relies on - it commits directly to `kubernetes/values/dev/*.yaml` and expects Argo CD to pick it up within its poll interval. |
| staging | yes | yes | yes | Staging exists to validate exactly what will be promoted to prod, so it should track Git as closely as dev. Promotion into staging happens through the `promote.yml` workflow, which opens a **pull request** rather than pushing directly - so a human still reviews the diff before it lands in `main`, even though Argo CD then applies it automatically. |
| prod | **no** (`automated` omitted) | n/a until synced | n/a | Argo CD will show `OutOfSync` the moment `main` changes, but applies nothing until a human explicitly runs `argocd app sync prod-<component>` (or clicks Sync in the UI). This is the deliberate production gate: review the PR, watch staging, then sync prod on your own schedule - not on CI's. |

Both dev and staging still get drift protection (`selfHeal: true`): if
someone runs `kubectl edit` against those namespaces, Argo CD reverts it on
the next reconcile loop. Prod does not self-heal *because* it isn't
auto-synced in the first place - the same manual step that deploys changes
is what you'd use to fix drift.

## Promotion workflow

```
dev (auto)  --[promote.yml: opens PR]-->  staging (auto once merged)  --[promote.yml: opens PR]-->  prod (manual argocd app sync)
```

Run **Actions -> Promote Image -> Run workflow**, choosing the source/target
environment and component. It copies the `image.repository`/`image.tag`
values from the source environment's values file to the target's and opens
a PR - merging that PR is the actual promotion.

## Verifying GitOps is working

```bash
argocd app list
argocd app get dev-backend
kubectl -n dev get pods -l app.kubernetes.io/component=backend

# Prove reconciliation: make an out-of-band change, watch Argo CD revert it (dev/staging only)
kubectl -n dev scale deployment/backend --replicas=5
argocd app get dev-backend   # shows OutOfSync, then Synced again shortly after
```

## Rollback

Two rollback mechanisms exist, at different layers:

1. **Argo CD application history** (fastest - rolls back the Helm release
   Argo CD manages, without touching Git):
   ```bash
   argocd app history dev-backend
   argocd app rollback dev-backend <ID>
   ```
   This is what `scripts/rollback.sh` wraps.

2. **Git revert** (the durable fix - makes the rollback the new desired
   state, so the next sync doesn't undo it):
   ```bash
   git revert <commit-that-bumped-the-image-tag>
   git push origin main
   ```
   For dev/staging this auto-applies; for prod, sync manually as usual.

Prefer (2) for anything you want to stick - an Argo CD-only rollback (1)
will be overwritten the next time something re-syncs from the still-newer
Git state.
