#!/bin/bash

# Script para configurar ArgoCD con la aplicación Backstage
set -e

echo "🔧 Configurando aplicación ArgoCD para Backstage..."

# Verificar que ArgoCD CLI está instalado (opcional)
if command -v argocd &> /dev/null; then
    echo "✅ ArgoCD CLI encontrado"
else
    echo "⚠️  ArgoCD CLI no encontrado, usando kubectl directamente"
fi

# Aplicar la aplicación ArgoCD
echo "📦 Aplicando aplicación ArgoCD..."
kubectl apply -f argocd/application.yaml

# Esperar a que la aplicación se cree
echo "⏳ Esperando a que se cree la aplicación..."
sleep 5

# Verificar estado de la aplicación
echo "🔍 Verificando estado de la aplicación..."
kubectl get application backstage -n argocd -o yaml

# Forzar sync inicial si es necesario
echo "🔄 Forzando sync inicial..."
kubectl patch application backstage -n argocd -p '{"operation":{"sync":{}}}' --type merge || true

echo "✅ Configuración de ArgoCD completada!"
echo ""
echo "🌐 Puedes ver la aplicación en: https://argocd.test.com"
echo "📱 Usuario: admin"
echo "🔐 Contraseña: Thomas#1109"