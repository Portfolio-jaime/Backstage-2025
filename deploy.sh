#!/bin/bash

# Colores para output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

echo -e "${CYAN}=== Despliegue de ArgoCD con Ingress para Docker Desktop ===${NC}"
echo ""

# Función para esperar a que los pods estén listos
wait_for_pods() {
    local namespace=$1
    local app_selector=$2
    local timeout=${3:-300}
    
    echo -e "${BLUE}Esperando a que los pods estén listos en namespace $namespace...${NC}"
    kubectl wait --for=condition=Ready pods -l $app_selector -n $namespace --timeout=${timeout}s
}

# Función para verificar si un recurso existe
resource_exists() {
    kubectl get $1 $2 -n $3 >/dev/null 2>&1
    return $?
}

# Verificar que estamos en Docker Desktop Kubernetes
echo -e "${BLUE}1. Verificando entorno Kubernetes...${NC}"
CLUSTER_INFO=$(kubectl cluster-info | grep "control plane")
if [[ $CLUSTER_INFO == *"127.0.0.1"* ]]; then
    echo -e "${GREEN}✓ Docker Desktop Kubernetes detectado${NC}"
else
    echo -e "${YELLOW}⚠ Advertencia: Este script está optimizado para Docker Desktop Kubernetes${NC}"
fi

# Paso 1: Crear namespace para ArgoCD
echo -e "\n${BLUE}2. Creando namespace para ArgoCD...${NC}"
if resource_exists "namespace" "argocd" ""; then
    echo -e "${GREEN}✓ Namespace 'argocd' ya existe${NC}"
else
    kubectl apply -f argocd/namespace.yaml
    echo -e "${GREEN}✓ Namespace 'argocd' creado${NC}"
fi

# Paso 2: Verificar/instalar ingress controller
echo -e "\n${BLUE}3. Verificando NGINX Ingress Controller...${NC}"
if resource_exists "namespace" "ingress-nginx" ""; then
    echo -e "${GREEN}✓ NGINX Ingress Controller ya existe${NC}"
else
    echo -e "${YELLOW}⚠ Instalando NGINX Ingress Controller para Docker Desktop...${NC}"
    kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/controller-v1.9.4/deploy/static/provider/cloud/deploy.yaml
    
    # Aplicar configuración específica de Docker Desktop (hostPort)
    echo -e "${BLUE}   Configurando hostPort para Docker Desktop...${NC}"
    kubectl patch deployment ingress-nginx-controller -n ingress-nginx --type='json' \
        -p='[{"op": "add", "path": "/spec/template/spec/containers/0/ports", "value": [{"containerPort": 80, "hostPort": 80, "protocol": "TCP"}, {"containerPort": 443, "hostPort": 443, "protocol": "TCP"}]}]'
    
    echo -e "${GREEN}✓ NGINX Ingress Controller instalado y configurado${NC}"
fi

# Esperar a que el ingress controller esté listo
echo -e "\n${BLUE}4. Esperando a que el ingress controller esté listo...${NC}"
wait_for_pods "ingress-nginx" "app.kubernetes.io/component=controller" 300

# Paso 3: Instalar ArgoCD
echo -e "\n${BLUE}5. Instalando ArgoCD...${NC}"
if resource_exists "deployment" "argocd-server" "argocd"; then
    echo -e "${GREEN}✓ ArgoCD ya está instalado${NC}"
else
    kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml
    echo -e "${GREEN}✓ ArgoCD instalado${NC}"
fi

# Esperar a que todos los pods de ArgoCD estén listos
echo -e "\n${BLUE}6. Esperando a que ArgoCD esté completamente listo...${NC}"
wait_for_pods "argocd" "app.kubernetes.io/part-of=argocd" 600

# Paso 4: Configurar ArgoCD en modo inseguro para ingress
echo -e "\n${BLUE}7. Configurando ArgoCD para modo inseguro...${NC}"
CURRENT_ARGS=$(kubectl get deployment argocd-server -n argocd -o json | jq -r '.spec.template.spec.containers[0].args[]?' | grep -c "\--insecure")
if [ "$CURRENT_ARGS" -eq 0 ]; then
    kubectl patch deployment argocd-server -n argocd --type='json' \
        -p='[{"op": "add", "path": "/spec/template/spec/containers/0/args/-", "value": "--insecure"}]'
    echo -e "${GREEN}✓ ArgoCD configurado en modo inseguro${NC}"
    
    # Esperar a que el pod se reinicie
    echo -e "${BLUE}   Esperando reinicio del servidor ArgoCD...${NC}"
    sleep 30
    wait_for_pods "argocd" "app.kubernetes.io/name=argocd-server" 300
else
    echo -e "${GREEN}✓ ArgoCD ya está configurado en modo inseguro${NC}"
fi

# Paso 5: Aplicar configuración de ingress
echo -e "\n${BLUE}8. Configurando ingress para ArgoCD...${NC}"
if resource_exists "ingress" "argocd-server-ingress" "argocd"; then
    kubectl delete ingress argocd-server-ingress -n argocd
    echo -e "${YELLOW}✓ Ingress anterior eliminado${NC}"
fi

kubectl apply -f argocd-ingress-http.yaml
echo -e "${GREEN}✓ Ingress configurado para HTTP/HTTPS${NC}"

# Paso 6: Configurar DNS local
echo -e "\n${BLUE}9. Configurando DNS local...${NC}"
if grep -q "argocd.test.com" /etc/hosts; then
    echo -e "${GREEN}✓ Entrada DNS ya existe en /etc/hosts${NC}"
else
    echo -e "${YELLOW}⚠ Configuración manual requerida:${NC}"
    echo "   Añade esta línea a /etc/hosts:"
    echo "   127.0.0.1 argocd.test.com"
    echo ""
    echo -e "${BLUE}   ¿Quieres que lo añada automáticamente? (requiere sudo) [y/N]:${NC}"
    read -r response
    if [[ "$response" =~ ^([yY][eE][sS]|[yY])$ ]]; then
        echo "127.0.0.1 argocd.test.com" | sudo tee -a /etc/hosts > /dev/null
        echo -e "${GREEN}✓ Entrada DNS añadida a /etc/hosts${NC}"
    else
        echo -e "${YELLOW}⚠ Por favor, añade manualmente la entrada a /etc/hosts${NC}"
    fi
fi

# Paso 7: Obtener credenciales de ArgoCD
echo -e "\n${BLUE}10. Obteniendo credenciales de ArgoCD...${NC}"
sleep 10  # Dar tiempo para que se genere el secret

ADMIN_PASSWORD=$(kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" 2>/dev/null | base64 -d 2>/dev/null)
if [ -n "$ADMIN_PASSWORD" ]; then
    echo -e "${GREEN}✓ Credenciales obtenidas exitosamente${NC}"
    echo -e "${YELLOW}Usuario:${NC} admin"
    echo -e "${YELLOW}Password:${NC} $ADMIN_PASSWORD"
else
    echo -e "${RED}✗ No se pudieron obtener las credenciales automáticamente${NC}"
    echo "   Inténtalo manualmente más tarde con:"
    echo "   kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath=\"{.data.password}\" | base64 -d"
fi

# Paso 8: Verificación final
echo -e "\n${BLUE}11. Verificación final...${NC}"

# Test de conectividad
echo -n "Testeando conectividad HTTP: "
HTTP_RESPONSE=$(curl -s -o /dev/null -w "%{http_code}" --max-time 10 http://argocd.test.com 2>/dev/null)
if [ "$HTTP_RESPONSE" = "200" ]; then
    echo -e "${GREEN}✓ OK ($HTTP_RESPONSE)${NC}"
else
    echo -e "${YELLOW}⚠ Respuesta: $HTTP_RESPONSE${NC}"
fi

echo -n "Testeando conectividad HTTPS: "
HTTPS_RESPONSE=$(curl -s -o /dev/null -w "%{http_code}" --max-time 10 -k https://argocd.test.com 2>/dev/null)
if [ "$HTTPS_RESPONSE" = "200" ]; then
    echo -e "${GREEN}✓ OK ($HTTPS_RESPONSE)${NC}"
else
    echo -e "${YELLOW}⚠ Respuesta: $HTTPS_RESPONSE${NC}"
fi

# Resumen final
echo -e "\n${CYAN}=== Despliegue Completado ===${NC}"
echo -e "${GREEN}✅ ArgoCD con Ingress para Docker Desktop instalado exitosamente${NC}"
echo ""
echo -e "${BLUE}URLs de acceso:${NC}"
echo -e "${YELLOW}HTTP:${NC}  http://argocd.test.com"
echo -e "${YELLOW}HTTPS:${NC} https://argocd.test.com"
echo ""
if [ -n "$ADMIN_PASSWORD" ]; then
    echo -e "${BLUE}Credenciales:${NC}"
    echo -e "${YELLOW}Usuario:${NC} admin"
    echo -e "${YELLOW}Password:${NC} $ADMIN_PASSWORD"
    echo ""
fi
echo -e "${BLUE}Comandos útiles:${NC}"
echo "• Verificación completa: ./verify.sh"
echo "• Estado de pods: kubectl get pods -n argocd"
echo "• Estado de ingress: kubectl get ingress -n argocd"
echo ""
echo -e "${GREEN}¡Puedes acceder ahora a ArgoCD desde tu navegador en https://argocd.test.com!${NC}"