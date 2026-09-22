# Observability

## What's deployed

[`scripts/install-monitoring.sh`](../scripts/install-monitoring.sh) installs
[kube-prometheus-stack](https://github.com/prometheus-community/helm-charts/tree/main/charts/kube-prometheus-stack)
into a `monitoring` namespace: the Prometheus Operator, Prometheus,
Alertmanager, Grafana, kube-state-metrics, and node-exporter. It's cluster
infrastructure, installed the same way as `ingress-nginx`/`cert-manager`/Argo
CD itself (a script running Helm directly) rather than through Argo CD -
see [gitops.md](gitops.md) for why that split exists. One instance for the
whole cluster, not one per environment, matching the
[cost guidance](../README.md#cost-considerations) to only stand up `dev`.

Run it after `install-nginx-ingress.sh` and before setting `metrics.enabled:
true` on any Helm chart - the ServiceMonitor CRD it creates
(`kubernetes/helm/backend/templates/servicemonitor.yaml`) requires the
Prometheus Operator's CRDs to already exist.

## What's scraped

- **Backend**: `/metrics` (Prometheus text format: `http_requests_total`,
  `http_request_duration_seconds`, ...), via
  [`prometheus-fastapi-instrumentator`](https://github.com/trallnag/prometheus-fastapi-instrumentator)
  and the chart's `ServiceMonitor`, enabled in `kubernetes/values/dev/backend.yaml`.
- **ingress-nginx**: already exposes `/metrics`
  (`controller.metrics.enabled=true` in `install-nginx-ingress.sh`); an
  `additionalServiceMonitors` entry in
  `kubernetes/values/monitoring/kube-prometheus-stack.yaml` picks it up.
- **Kubernetes/node metrics**: kube-state-metrics and node-exporter, both
  bundled and enabled by default.
- **Frontend is not scraped.** The nginx container serving the built React
  app has no `/metrics` endpoint - adding one would mean running the
  `nginx-prometheus-exporter` sidecar, left out here to keep the demo
  footprint small. HTTP-level visibility into frontend traffic still comes
  from the ingress-nginx metrics above.

## Alerts

Defined in `additionalPrometheusRulesMap` in
`kubernetes/values/monitoring/kube-prometheus-stack.yaml`:

| Alert | Condition | Severity |
|---|---|---|
| `BackendDown` | no `up{job="backend"}` target for 2m | critical |
| `BackendHighErrorRate` | 5xx ratio > 5% over 5m | warning |
| `BackendHighLatencyP95` | p95 request latency > 1s over 10m | warning |

These fire into the bundled Alertmanager. No external receiver (Slack,
PagerDuty, email) is configured by default - wire one up via
`alertmanager.config.receivers` in the values file once you have somewhere
for alerts to actually go.

## Dashboards

`kubernetes/monitoring/dashboards/backend-api-dashboard.yaml` is a
ConfigMap (label `grafana_dashboard: "1"`) that Grafana's sidecar
auto-imports: request rate, 5xx error ratio, p95 latency, and pod restarts
for the backend, all keyed to the same metric names the alerts use.
`install-monitoring.sh` applies it directly since, like the stack itself,
it's cluster-wide rather than per-environment.

Everything else (Kubernetes cluster/node dashboards, etc.) comes from
kube-prometheus-stack's own bundled default dashboards
(`grafana.defaultDashboardsEnabled`, on by default).

## Accessing Grafana and Prometheus

No ingress is exposed by default (same reasoning as
[TLS being off by default](../README.md#ingress-and-tls) - a demo cluster
usually has no DNS pointed at it). Port-forward instead:

```bash
kubectl -n monitoring get secret kube-prometheus-stack-grafana \
  -o jsonpath='{.data.admin-password}' | base64 -d
kubectl -n monitoring port-forward svc/kube-prometheus-stack-grafana 3000:80
# http://localhost:3000, user: admin

kubectl -n monitoring port-forward svc/kube-prometheus-stack-prometheus 9090:9090
# http://localhost:9090
```

The Grafana admin password is generated fresh by `install-monitoring.sh` on
every install (`openssl rand -base64 24`, passed via `--set
grafana.adminPassword`) - it is never the chart's `prom-operator` default,
and it is never committed to this repository.

## Requires a live cluster

Everything above requires a real AKS cluster with `install-nginx-ingress.sh`
already run. It has not been exercised against a live cluster as part of
this change - see the root README's
[Validation status](../README.md#validation-status) for what has and hasn't
been verified.
