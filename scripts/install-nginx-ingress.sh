#!/usr/bin/env bash
# Installs the official NGINX ingress controller. Run once per cluster
# before applying the ingress Argo CD Applications.
set -euo pipefail

helm repo add ingress-nginx https://kubernetes.github.io/ingress-nginx
helm repo update

helm upgrade --install ingress-nginx ingress-nginx/ingress-nginx \
  --namespace ingress-nginx \
  --create-namespace \
  --set controller.metrics.enabled=true

echo
echo "Waiting for the public IP to be assigned..."
kubectl get service ingress-nginx-controller -n ingress-nginx -w
