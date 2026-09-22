#!/usr/bin/env bash
# Installs kube-prometheus-stack (Prometheus, Grafana, Alertmanager,
# kube-state-metrics, node-exporter) plus this repo's alert rules and
# dashboard. Cluster infrastructure, like ingress-nginx/cert-manager/Argo CD
# - installed once via Helm directly, not through Argo CD GitOps. Run after
# install-nginx-ingress.sh (its /metrics endpoint is scraped automatically)
# and before enabling metrics.enabled on the backend Helm chart, since that
# chart's ServiceMonitor requires the Prometheus Operator CRDs this installs.
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"

helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo update

# Generated fresh per install rather than using the chart's "prom-operator"
# default - never committed, retrieve it with the command printed below.
GRAFANA_PASSWORD="$(openssl rand -base64 24)"

helm upgrade --install kube-prometheus-stack prometheus-community/kube-prometheus-stack \
  --namespace monitoring \
  --create-namespace \
  --set grafana.adminPassword="${GRAFANA_PASSWORD}" \
  -f "${REPO_ROOT}/kubernetes/values/monitoring/kube-prometheus-stack.yaml"

kubectl wait --for=condition=Available --timeout=180s -n monitoring deployment/kube-prometheus-stack-operator

kubectl apply -f "${REPO_ROOT}/kubernetes/monitoring/dashboards/"

echo
echo "Monitoring stack installed."
echo "Grafana admin password (re-derive any time - it's stored in the Secret below):"
echo "  kubectl -n monitoring get secret kube-prometheus-stack-grafana -o jsonpath='{.data.admin-password}' | base64 -d"
echo "Port-forward the UI with:"
echo "  kubectl -n monitoring port-forward svc/kube-prometheus-stack-grafana 3000:80"
echo "Port-forward Prometheus with:"
echo "  kubectl -n monitoring port-forward svc/kube-prometheus-stack-prometheus 9090:9090"
