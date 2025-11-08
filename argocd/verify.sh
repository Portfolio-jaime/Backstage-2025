#!/bin/bash

# Colores para output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

echo -e "${CYAN}=== Verificación Final de ArgoCD con Ingress para Docker Desktop ===${NC}"
echo ""

# Verificar ArgoCD namespace
echo -e "${BLUE}1. Verificando namespace de ArgoCD...${NC}"
kubectl get namespace argocd >/dev/null 2>&1
if [ $? -eq 0 ]; then
    echo -e "${GREEN}✓${NC} Namespace 'argocd' existe"
else
    echo -e "${RED}✗${NC} Namespace 'argocd' no encontrado"
    exit 1
fi

# Verificar pods de ArgoCD
echo -e "\n${BLUE}2. Verificando pods de ArgoCD...${NC}"
ARGOCD_PODS=$(kubectl get pods -n argocd -o json | jq '.items | length')
RUNNING_PODS=$(kubectl get pods -n argocd --field-selector=status.phase=Running -o json | jq '.items | length')

echo "Total de pods: $ARGOCD_PODS"
echo "Pods en ejecución: $RUNNING_PODS"

kubectl get pods -n argocd --no-headers | while read line; do
    POD_NAME=$(echo $line | awk '{print $1}')
    POD_STATUS=$(echo $line | awk '{print $3}')
    if [ "$POD_STATUS" = "Running" ]; then
        echo -e "${GREEN}✓${NC} $POD_NAME: $POD_STATUS"
    else
        echo -e "${RED}✗${NC} $POD_NAME: $POD_STATUS"
    fi
done

# Verificar servicios de ArgoCD
echo -e "\n${BLUE}3. Verificando servicios de ArgoCD...${NC}"
kubectl get svc -n argocd argocd-server >/dev/null 2>&1
if [ $? -eq 0 ]; then
    echo -e "${GREEN}✓${NC} Servicio argocd-server encontrado"
    kubectl get svc -n argocd argocd-server
else
    echo -e "${RED}✗${NC} Servicio argocd-server no encontrado"
fi

# Verificar ingress controller
echo -e "\n${BLUE}4. Verificando NGINX Ingress Controller...${NC}"
kubectl get namespace ingress-nginx >/dev/null 2>&1
if [ $? -eq 0 ]; then
    echo -e "${GREEN}✓${NC} Namespace ingress-nginx existe"
    INGRESS_PODS=$(kubectl get pods -n ingress-nginx --field-selector=status.phase=Running -o json | jq '.items | length')
    echo "Pods del ingress controller en ejecución: $INGRESS_PODS"
    
    echo -e "\n${BLUE}   Estado del ingress controller:${NC}"
    kubectl get pods -n ingress-nginx -o wide
    
    echo -e "\n${BLUE}   Servicio del ingress controller:${NC}"
    kubectl get svc -n ingress-nginx
else
    echo -e "${RED}✗${NC} Namespace ingress-nginx no encontrado"
fi

# Verificar ingress de ArgoCD
echo -e "\n${BLUE}5. Verificando ingress de ArgoCD...${NC}"
kubectl get ingress -n argocd argocd-server-ingress >/dev/null 2>&1
if [ $? -eq 0 ]; then
    echo -e "${GREEN}✓${NC} Ingress argocd-server-ingress encontrado"
    kubectl get ingress -n argocd argocd-server-ingress -o wide
    
    echo -e "\n${BLUE}   Configuración del ingress:${NC}"
    kubectl describe ingress -n argocd argocd-server-ingress | grep -A 10 -B 5 "Rules\|Host\|Backend"
else
    echo -e "${RED}✗${NC} Ingress argocd-server-ingress no encontrado"
fi

# Verificar /etc/hosts
echo -e "\n${BLUE}6. Verificando configuración de /etc/hosts...${NC}"
grep "argocd.test.com" /etc/hosts >/dev/null 2>&1
if [ $? -eq 0 ]; then
    echo -e "${GREEN}✓${NC} Entrada encontrada en /etc/hosts:"
    grep "argocd.test.com" /etc/hosts
else
    echo -e "${YELLOW}⚠${NC} No se encontró entrada en /etc/hosts"
    echo "   Para acceder desde el navegador, añade esta línea a /etc/hosts:"
    echo "   127.0.0.1 argocd.test.com"
fi

# Verificar conectividad
echo -e "\n${BLUE}7. Verificando conectividad web...${NC}"

# Test HTTP
echo -n "Testeando HTTP (puerto 80): "
HTTP_RESPONSE=$(curl -s -o /dev/null -w "%{http_code}" --max-time 10 http://argocd.test.com 2>/dev/null)
if [ "$HTTP_RESPONSE" = "200" ]; then
    echo -e "${GREEN}✓ Respuesta: $HTTP_RESPONSE (OK)${NC}"
elif [ "$HTTP_RESPONSE" = "307" ]; then
    echo -e "${GREEN}✓ Respuesta: $HTTP_RESPONSE (Redirect a HTTPS)${NC}"
else
    echo -e "${YELLOW}⚠ Respuesta: $HTTP_RESPONSE${NC}"
fi

# Test HTTPS
echo -n "Testeando HTTPS (puerto 443): "
HTTPS_RESPONSE=$(curl -s -o /dev/null -w "%{http_code}" --max-time 10 -k https://argocd.test.com 2>/dev/null)
if [ "$HTTPS_RESPONSE" = "200" ]; then
    echo -e "${GREEN}✓ Respuesta: $HTTPS_RESPONSE (OK)${NC}"
elif [ "$HTTPS_RESPONSE" = "000" ]; then
    echo -e "${RED}✗ No se puede conectar${NC}"
else
    echo -e "${YELLOW}⚠ Respuesta: $HTTPS_RESPONSE${NC}"
fi

# Verificar configuración específica de Docker Desktop
echo -e "\n${BLUE}8. Configuración específica de Docker Desktop...${NC}"
echo -n "Verificando hostPort en ingress controller: "
HOSTPORT_CONFIG=$(kubectl get deployment -n ingress-nginx ingress-nginx-controller -o json | jq '.spec.template.spec.containers[0].ports[]? | select(.hostPort)')
if [ -n "$HOSTPORT_CONFIG" ]; then
    echo -e "${GREEN}✓ Configurado${NC}"
    echo "$HOSTPORT_CONFIG" | jq -r '"  Puerto " + (.containerPort|tostring) + " → hostPort " + (.hostPort|tostring)'
else
    echo -e "${YELLOW}⚠ No configurado (podría requerir configuración manual)${NC}"
fi

# Verificar ArgoCD server modo inseguro
echo -n "Verificando ArgoCD server en modo insecuro: "
INSECURE_FLAG=$(kubectl get deployment -n argocd argocd-server -o json | jq -r '.spec.template.spec.containers[0].args[]? | select(. == "--insecure")')
if [ -n "$INSECURE_FLAG" ]; then
    echo -e "${GREEN}✓ Configurado${NC}"
else
    echo -e "${YELLOW}⚠ No configurado${NC}"
fi

# Obtener credenciales de admin
echo -e "\n${BLUE}9. Credenciales de ArgoCD...${NC}"
ADMIN_PASSWORD=$(kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" 2>/dev/null | base64 -d 2>/dev/null)
if [ -n "$ADMIN_PASSWORD" ]; then
    echo -e "${YELLOW}Usuario:${NC} admin"
    echo -e "${YELLOW}Password:${NC} $ADMIN_PASSWORD"
else
    echo -e "${RED}✗${NC} No se pudo obtener la contraseña de admin"
fi

# URLs de acceso y resumen
echo -e "\n${BLUE}10. URLs de acceso...${NC}"
echo -e "${GREEN}HTTP:${NC}  http://argocd.test.com (sin puerto específico)"
echo -e "${GREEN}HTTPS:${NC} https://argocd.test.com (sin puerto específico)"

# Test final del navegador
echo -e "\n${CYAN}=== Test final de navegador ===${NC}"
echo -e "Ahora deberías poder acceder a ArgoCD directamente desde tu navegador en:"
echo -e "${YELLOW}https://argocd.test.com${NC}"
echo ""
echo -e "${GREEN}¡Configuración de ArgoCD con Ingress para Docker Desktop completada exitosamente!${NC}"
echo ""
echo -e "${BLUE}Notas importantes:${NC}"
echo -e "• El ingress está configurado para trabajar con Docker Desktop Kubernetes"
echo -e "• ArgoCD está ejecutándose en modo inseguro para permitir proxy reverso"
echo -e "• El acceso funciona sin especificar puertos (80/443 estándar)"
echo -e "• Asegúrate de tener la entrada en /etc/hosts para resolución DNS local"