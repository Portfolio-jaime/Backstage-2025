#!/bin/bash

# Script para aplicar secretos de forma segura en producción
# Este script debe ser ejecutado manualmente en el servidor o via CI/CD segura

set -euo pipefail

echo "🔐 Configurando secretos de Backstage para producción..."

# Verificar que estamos en el namespace correcto
kubectl config set-context --current --namespace=backstage

# Crear secretos usando variables de entorno (más seguro)
kubectl create secret generic backstage-secrets \
  --from-literal=POSTGRES_HOST="${POSTGRES_HOST:-postgres}" \
  --from-literal=POSTGRES_PORT="${POSTGRES_PORT:-5432}" \
  --from-literal=POSTGRES_USER="${POSTGRES_USER:-backstage}" \
  --from-literal=POSTGRES_PASSWORD="${POSTGRES_PASSWORD}" \
  --from-literal=POSTGRES_DB="${POSTGRES_DB:-backstage}" \
  --from-literal=ARGOCD_URL="${ARGOCD_URL}" \
  --from-literal=ARGOCD_USERNAME="${ARGOCD_USERNAME}" \
  --from-literal=ARGOCD_PASSWORD="${ARGOCD_PASSWORD}" \
  --from-literal=AUTH_SECRET="${AUTH_SECRET}" \
  --from-literal=GITHUB_TOKEN="${GITHUB_TOKEN:-}" \
  --from-literal=AUTH_GITHUB_CLIENT_ID="${AUTH_GITHUB_CLIENT_ID:-}" \
  --from-literal=AUTH_GITHUB_CLIENT_SECRET="${AUTH_GITHUB_CLIENT_SECRET:-}" \
  --dry-run=client -o yaml | kubectl apply -f -

# ArgoCD auth token
kubectl create secret generic argocd-auth \
  --from-literal=ARGOCD_AUTH_TOKEN="${ARGOCD_AUTH_TOKEN}" \
  --dry-run=client -o yaml | kubectl apply -f -

echo "✅ Secretos aplicados correctamente"

# Reiniciar deployment para aplicar nuevos secretos
echo "🔄 Reiniciando deployment..."
kubectl rollout restart deployment/backstage

echo "✅ Listo! Monitorea el rollout con: kubectl rollout status deployment/backstage"