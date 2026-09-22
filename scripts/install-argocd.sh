#!/usr/bin/env bash
# Installs Argo CD and applies this repo's AppProject + app-of-apps roots.
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"

kubectl create namespace argocd --dry-run=client -o yaml | kubectl apply -f -
kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml

echo "Waiting for Argo CD server to become available..."
kubectl wait --for=condition=Available --timeout=180s -n argocd deployment/argocd-server

kubectl apply -f "${REPO_ROOT}/kubernetes/namespaces/"
kubectl apply -f "${REPO_ROOT}/argocd/projects/aks-platform-project.yaml"
kubectl apply -f "${REPO_ROOT}/argocd/bootstrap/"

echo
echo "Argo CD installed. Get the initial admin password with:"
echo "  kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath='{.data.password}' | base64 -d"
echo "Then port-forward the UI with:"
echo "  kubectl -n argocd port-forward svc/argocd-server 8080:443"
