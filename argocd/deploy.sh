#!/bin/bash

# Script para desplegar ArgoCD en Kubernetes
# Este script despliega ArgoCD con ingress configurado para argocd.test.com

set -e

echo "🚀 Iniciando el despliegue de ArgoCD..."

# 0. Verificar si existe un ingress controller
echo "🔍 Verificando Ingress Controller..."
if ! kubectl get pods -n ingress-nginx -l app.kubernetes.io/component=controller 2>/dev/null | grep -q Running; then
    echo "⚠️  No se encontró NGINX Ingress Controller funcionando"
    echo "💡 Ejecuta primero: ./install-ingress-controller.sh"
    echo ""
    read -p "¿Quieres instalar NGINX Ingress Controller ahora? (y/N): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        echo "📦 Instalando NGINX Ingress Controller..."
        ./install-ingress-controller.sh
    else
        echo "❌ Ingress Controller requerido para el funcionamiento del ingress"
        exit 1
    fi
else
    echo "✅ NGINX Ingress Controller encontrado y funcionando"
fi

# 1. Crear el namespace si no existe
echo "📂 Creando namespace argocd..."
kubectl apply -f namespace.yaml

# 2. Instalar ArgoCD usando el manifiesto oficial
echo "⚙️ Instalando ArgoCD..."
kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml

# 3. Esperar a que los pods estén listos
echo "⏳ Esperando a que los pods de ArgoCD estén listos..."
kubectl wait --for=condition=Ready pods --all -n argocd --timeout=600s

# 4. Aplicar el ingress
echo "🌐 Configurando ingress para ArgoCD..."
kubectl apply -f argocd-ingress.yaml

# 5. Generar certificado self-signed para desarrollo (opcional)
echo "🔐 Creando certificado self-signed para desarrollo..."
openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
  -keyout tls.key -out tls.crt \
  -subj "/CN=argocd.test.com/O=argocd.test.com"

kubectl create secret tls argocd-server-tls \
  --key tls.key --cert tls.crt -n argocd \
  --dry-run=client -o yaml | kubectl apply -f -

# Limpiar archivos temporales
rm -f tls.key tls.crt

# 6. Obtener la contraseña inicial de admin
echo "🔑 Obteniendo contraseña inicial de admin..."
ADMIN_PASSWORD=$(kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d 2>/dev/null || echo "secret-not-found")

# 7. Mostrar información de acceso
echo ""
echo "✅ ¡ArgoCD se ha desplegado exitosamente!"
echo ""
echo "📋 Información de acceso:"
echo "  URL: https://argocd.test.com"
echo "  Usuario: admin"
echo "  Contraseña: $ADMIN_PASSWORD"
echo ""
echo "📝 Notas importantes:"
echo "  1. Asegúrate de que tu Ingress Controller esté funcionando"
echo "  2. Agrega 'argocd.test.com' a tu /etc/hosts apuntando a tu cluster IP"
echo "  3. La contraseña inicial se puede cambiar desde la interfaz web"
echo "  4. Para producción, configura un certificado TLS válido"
echo ""
echo "🔧 Comandos útiles:"
echo "  # Ver estado de los pods:"
echo "  kubectl get pods -n argocd"
echo ""
echo "  # Ver logs del servidor:"
echo "  kubectl logs -n argocd deployment/argocd-server"
echo ""
echo "  # Port-forward para acceso directo (alternativa al ingress):"
echo "  kubectl port-forward svc/argocd-server -n argocd 8080:443"
echo "  # Luego acceder a: https://localhost:8080"