#!/usr/bin/env bash
# Installs the Kyverno admission controller. Cluster infrastructure, like
# ingress-nginx/cert-manager/Argo CD itself - installed once via Helm
# directly. The policies it enforces are NOT installed by this script: they
# are GitOps-managed (argocd/applications/platform/kyverno-policies.yaml),
# since policy changes are exactly the kind of thing worth a PR review. Run
# install-argocd.sh first so that Application picks them up automatically.
set -euo pipefail

helm repo add kyverno https://kyverno.github.io/kyverno/
helm repo update

helm upgrade --install kyverno kyverno/kyverno \
  --namespace kyverno \
  --create-namespace

kubectl wait --for=condition=Available --timeout=180s -n kyverno deployment/kyverno-admission-controller

echo
echo "Kyverno installed. Policies apply automatically once Argo CD syncs"
echo "argocd/applications/platform/kyverno-policies.yaml. Check status with:"
echo "  kubectl get clusterpolicies"
