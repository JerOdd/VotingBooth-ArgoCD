#!/bin/bash

set -e

ENV=$1

if [[ -z "$ENV" ]]; then
    echo "Usage: $0 [local|dev|prod]"
    exit 1
fi

echo ">> Bootstrapping environment: $ENV"

kubectl create namespace argocd --dry-run=client -o yaml | kubectl apply -f -

echo ">> Installing ArgoCD..."
kubectl apply -f bootstrap/install-argocd.yaml

echo ">> Waiting for ArgoCD to be ready..."
kubectl rollout status deployment argocd-server -n argocd

echo ">> Applying ArgoCD root app for $ENV"
kubectl apply -f root-apps/${ENV}-root.yaml

echo ">> Bootstrap complete for $ENV!"