#!/usr/bin/env bash
# Installs the Argo Rollouts controller and CRDs. Cluster infrastructure,
# like Argo CD itself - installed once via kubectl, not through GitOps. Run
# before applying the backend chart, since its Rollout/AnalysisTemplate
# resources have no controller to reconcile them otherwise.
set -euo pipefail

kubectl create namespace argo-rollouts --dry-run=client -o yaml | kubectl apply -f -
kubectl apply -n argo-rollouts -f https://github.com/argoproj/argo-rollouts/releases/latest/download/install.yaml

echo "Waiting for the Argo Rollouts controller to become available..."
kubectl wait --for=condition=Available --timeout=180s -n argo-rollouts deployment/argo-rollouts

echo
echo "Argo Rollouts installed. Install the kubectl plugin to watch canaries:"
echo "  https://argo-rollouts.readthedocs.io/en/stable/installation/#kubectl-plugin-installation"
echo "Watch a rollout with:"
echo "  kubectl argo rollouts get rollout backend -n dev --watch"
