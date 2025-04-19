#!/bin/bash

set -e

ENV=$1

if [[ -z "$ENV" ]]; then
    echo "Usage: $0 [local|dev|prod]"
    exit 1
fi

echo ">> Bootstrapping environment: $ENV"

# 1. Create namespace
kubectl apply -f bootstrap/argocd-namespace.yaml

# 2. Pre-install Argo CD (to get CRDs)
echo ">> Pre-installing Argo CD to ensure CRDs are available..."
kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml

# 3. Wait for CRDs
echo ">> Waiting for Argo CD CRDs to become available..."
until kubectl get crd applications.argoproj.io &>/dev/null; do
    echo "   Waiting for CRDs..."
    sleep 2
done

# 4. Apply Argo CD Application
echo ">> Installing Argo CD via Application..."
kubectl apply -f bootstrap/install-argocd.yaml

# 5. Wait for Argo CD server to be ready
echo ">> Waiting for argocd-server deployment to be ready..."
kubectl rollout status deployment argocd-server -n argocd

# 6. Wait for install-argocd Application to be Healthy
echo ">> Waiting for install-argocd Application to be Healthy..."
for i in {1..30}; do
  STATUS=$(kubectl get app install-argocd -n argocd -o jsonpath="{.status.health.status}" 2>/dev/null || echo "Missing")
  echo "   Status: $STATUS"
  if [[ "$STATUS" == "Healthy" ]]; then
    break
  fi
  sleep 5
done

# 7. Apply root application
if [[ ! -f "root-apps/${ENV}-root.yaml" ]]; then
    echo "❌ root-apps/${ENV}-root.yaml not found!"
    exit 1
fi

echo ">> Applying ArgoCD root app for $ENV"
kubectl apply -f root-apps/${ENV}-root.yaml

# 8. Retrieve Argo CD admin password
echo "🔑 Argo CD admin password:"
kubectl -n argocd get secret argocd-initial-admin-secret \
  -o jsonpath="{.data.password}" | base64 -d && echo

# 9. If ENV is local, port-forward
if [[ "$ENV" == "local" ]]; then
    echo ">> Port forwarding Argo CD server to https://localhost:8080"
    echo "👉 Access the UI at: https://localhost:8080"
    echo "👉 Login with username: admin"
    kubectl port-forward svc/argocd-server -n argocd 8080:443
fi

echo "✅ Bootstrap complete for $ENV!"