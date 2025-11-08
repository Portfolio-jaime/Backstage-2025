#!/bin/bash

# Script de despliegue de Backstage en Kubernetes

# Colores para output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

echo -e "${CYAN}=== Despliegue de Backstage en Kubernetes ===${NC}"
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

# Verificar que estamos en el directorio correcto
if [ ! -f "kubernetes/namespace.yaml" ]; then
    echo -e "${RED}❌ No se encontraron los manifiestos de Kubernetes. Ejecuta desde el directorio backstage.${NC}"
    exit 1
fi

# Verificar conectividad con Kubernetes
echo -e "${BLUE}1. Verificando conectividad con Kubernetes...${NC}"
if ! kubectl cluster-info >/dev/null 2>&1; then
    echo -e "${RED}❌ No se puede conectar al cluster Kubernetes${NC}"
    exit 1
fi

CLUSTER_INFO=$(kubectl cluster-info | head -n1)
echo -e "${GREEN}✓ Conectado a cluster: $CLUSTER_INFO${NC}"

# Verificar ArgoCD
echo -e "\n${BLUE}2. Verificando ArgoCD...${NC}"
if kubectl get namespace argocd >/dev/null 2>&1; then
    echo -e "${GREEN}✓ ArgoCD namespace encontrado${NC}"
    ARGOCD_PODS=$(kubectl get pods -n argocd --field-selector=status.phase=Running -o json | jq '.items | length' 2>/dev/null || echo "0")
    echo -e "${GREEN}✓ ArgoCD pods ejecutándose: $ARGOCD_PODS${NC}"
else
    echo -e "${YELLOW}⚠ ArgoCD no encontrado. Asegúrate de que esté desplegado.${NC}"
fi

# Paso 1: Crear namespace
echo -e "\n${BLUE}3. Creando namespace backstage...${NC}"
kubectl apply -f kubernetes/namespace.yaml
echo -e "${GREEN}✓ Namespace aplicado${NC}"

# Paso 2: Aplicar RBAC
echo -e "\n${BLUE}4. Configurando RBAC...${NC}"
kubectl apply -f kubernetes/rbac.yaml
echo -e "${GREEN}✓ ServiceAccount y RBAC configurados${NC}"

# Paso 3: Aplicar Secrets
echo -e "\n${BLUE}5. Aplicando secrets...${NC}"
kubectl apply -f kubernetes/secrets.yaml
echo -e "${GREEN}✓ Secrets aplicados${NC}"
echo -e "${YELLOW}💡 Verifica que las credenciales en secrets.yaml sean correctas${NC}"

# Paso 4: Aplicar ConfigMaps
echo -e "\n${BLUE}6. Aplicando configuración...${NC}"
kubectl apply -f kubernetes/configmap.yaml
kubectl apply -f kubernetes/catalog.yaml
echo -e "${GREEN}✓ ConfigMaps aplicados${NC}"

# Paso 5: Desplegar PostgreSQL
echo -e "\n${BLUE}7. Desplegando PostgreSQL...${NC}"
kubectl apply -f kubernetes/postgres.yaml
echo -e "${GREEN}✓ PostgreSQL desplegado${NC}"

# Esperar a que PostgreSQL esté listo
echo -e "${BLUE}   Esperando a que PostgreSQL esté listo...${NC}"
wait_for_pods "backstage" "app.kubernetes.io/name=postgres" 300

# Paso 6: Desplegar Redis
echo -e "\n${BLUE}8. Desplegando Redis...${NC}"
kubectl apply -f kubernetes/redis.yaml
echo -e "${GREEN}✓ Redis desplegado${NC}"

# Esperar a que Redis esté listo
echo -e "${BLUE}   Esperando a que Redis esté listo...${NC}"
wait_for_pods "backstage" "app.kubernetes.io/name=redis" 180

# Paso 7: Desplegar Backstage (comentado hasta tener imagen)
echo -e "\n${BLUE}9. Preparando despliegue de Backstage...${NC}"
echo -e "${YELLOW}⚠ NOTA: El deployment de Backstage requiere una imagen Docker construida.${NC}"
echo -e "${YELLOW}   Actualiza la imagen en kubernetes/backstage.yaml antes de continuar.${NC}"
echo ""
echo -e "${BLUE}¿Quieres aplicar el deployment de Backstage ahora? (y/N):${NC}"
read -r response
if [[ "$response" =~ ^([yY][eE][sS]|[yY])$ ]]; then
    kubectl apply -f kubernetes/backstage.yaml
    echo -e "${GREEN}✓ Backstage deployment aplicado${NC}"
    
    # Esperar a que Backstage esté listo
    echo -e "${BLUE}   Esperando a que Backstage esté listo...${NC}"
    wait_for_pods "backstage" "app.kubernetes.io/name=backstage" 600
else
    echo -e "${YELLOW}⚠ Deployment de Backstage omitido${NC}"
fi

# Paso 8: Configurar Ingress
echo -e "\n${BLUE}10. Configurando Ingress...${NC}"
kubectl apply -f kubernetes/ingress.yaml
echo -e "${GREEN}✓ Ingress configurado${NC}"

# Paso 9: Configurar DNS
echo -e "\n${BLUE}11. Configurando DNS local...${NC}"
if grep -q "backstage.test.com" /etc/hosts; then
    echo -e "${GREEN}✓ Entrada DNS ya existe${NC}"
else
    echo -e "${YELLOW}⚠ Añade estas líneas a /etc/hosts:${NC}"
    echo "   127.0.0.1 backstage.test.com"
    echo "   127.0.0.1 backstage-api.test.com"
    echo ""
    echo -e "${BLUE}¿Quieres añadirlas automáticamente? (requiere sudo) [y/N]:${NC}"
    read -r response
    if [[ "$response" =~ ^([yY][eE][sS]|[yY])$ ]]; then
        echo "127.0.0.1 backstage.test.com" | sudo tee -a /etc/hosts
        echo "127.0.0.1 backstage-api.test.com" | sudo tee -a /etc/hosts
        echo -e "${GREEN}✓ Entradas DNS añadidas${NC}"
    fi
fi

# Verificación final
echo -e "\n${BLUE}12. Verificación del despliegue...${NC}"

echo -e "\n${BLUE}Namespaces:${NC}"
kubectl get namespaces | grep -E "(backstage|argocd)"

echo -e "\n${BLUE}Pods en namespace backstage:${NC}"
kubectl get pods -n backstage -o wide

echo -e "\n${BLUE}Servicios en namespace backstage:${NC}"
kubectl get services -n backstage

echo -e "\n${BLUE}Ingress:${NC}"
kubectl get ingress -n backstage

echo -e "\n${BLUE}Secrets y ConfigMaps:${NC}"
kubectl get secrets,configmaps -n backstage

# Resumen final
echo -e "\n${CYAN}=== Resumen del Despliegue ===${NC}"
echo -e "${GREEN}✅ Backstage configurado en Kubernetes${NC}"
echo ""
echo -e "${BLUE}📁 Componentes desplegados:${NC}"
echo -e "   • Namespace: backstage"
echo -e "   • PostgreSQL: Base de datos persistente"
echo -e "   • Redis: Cache y sesiones"
echo -e "   • RBAC: Permisos para leer recursos K8s"
echo -e "   • ConfigMaps: Configuración y catálogo"
echo -e "   • Secrets: Credenciales (ArgoCD: admin/Thomas#1109)"
echo -e "   • Ingress: backstage.test.com"
echo ""
echo -e "${BLUE}🔧 Próximos pasos:${NC}"
echo "1. Construir imagen Docker de Backstage"
echo "2. Actualizar kubernetes/backstage.yaml con tu imagen"
echo "3. Aplicar: kubectl apply -f kubernetes/backstage.yaml"
echo "4. Verificar: kubectl get pods -n backstage"
echo ""
echo -e "${BLUE}🌐 URLs (cuando esté funcionando):${NC}"
echo -e "   • Backstage: ${GREEN}http://backstage.test.com${NC}"
echo -e "   • ArgoCD: ${GREEN}https://argocd.test.com${NC}"
echo ""
echo -e "${BLUE}🔑 Credenciales ArgoCD:${NC}"
echo -e "   • Usuario: admin"
echo -e "   • Password: Thomas#1109"
echo ""
echo -e "${YELLOW}💡 Para desarrollo local, usa: ./start-dev.sh${NC}"
echo ""
echo -e "${GREEN}¡Despliegue base completado! 🎉${NC}"