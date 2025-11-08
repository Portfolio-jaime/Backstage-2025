#!/bin/bash

# Colores para output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

echo -e "${CYAN}=== Instalación de NGINX Ingress Controller para Docker Desktop ===${NC}"
echo ""

# Función para detectar el tipo de cluster
detect_cluster_type() {
    local cluster_info=$(kubectl cluster-info 2>/dev/null | head -n1)
    local node_name=$(kubectl get nodes -o jsonpath='{.items[0].metadata.name}' 2>/dev/null)
    
    # Docker Desktop detection
    if [[ $cluster_info == *"127.0.0.1"* ]] || [[ $node_name == *"docker-desktop"* ]]; then
        echo "docker-desktop"
    elif [[ $node_name == *"microk8s"* ]]; then
        echo "microk8s"
    elif [[ $node_name == *"kind"* ]]; then
        echo "kind"
    elif [[ $node_name == *"minikube"* ]]; then
        echo "minikube"
    else
        echo "cloud"
    fi
}

# Función para esperar a que los pods estén listos
wait_for_pods() {
    local namespace=$1
    local timeout=${2:-300}
    
    echo -e "${BLUE}Esperando a que los pods estén listos en namespace $namespace...${NC}"
    kubectl wait --for=condition=Ready pods --all -n $namespace --timeout=${timeout}s
}

# Detectar tipo de cluster
CLUSTER_TYPE=$(detect_cluster_type)
echo -e "${BLUE}Tipo de cluster detectado: ${YELLOW}$CLUSTER_TYPE${NC}"

# Verificar si ya existe
echo -e "\n${BLUE}1. Verificando instalación existente...${NC}"
kubectl get namespace ingress-nginx >/dev/null 2>&1
if [ $? -eq 0 ]; then
    echo -e "${GREEN}✓ NGINX Ingress Controller ya está instalado${NC}"
    kubectl get pods -n ingress-nginx
    exit 0
fi

case $CLUSTER_TYPE in
    "docker-desktop")
        echo -e "\n${BLUE}2. Instalando NGINX Ingress Controller para Docker Desktop...${NC}"
        
        # Instalar el ingress controller estándar
        kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/controller-v1.9.4/deploy/static/provider/cloud/deploy.yaml
        
        # Esperar a que el deployment esté disponible
        echo -e "${BLUE}3. Esperando a que el deployment esté disponible...${NC}"
        kubectl wait --for=condition=Available deployment/ingress-nginx-controller -n ingress-nginx --timeout=300s
        
        # Configurar hostPort específico para Docker Desktop
        echo -e "\n${BLUE}4. Configurando hostPort para Docker Desktop...${NC}"
        kubectl patch deployment ingress-nginx-controller -n ingress-nginx --type='json' \
            -p='[{"op": "add", "path": "/spec/template/spec/containers/0/ports", "value": [{"containerPort": 80, "hostPort": 80, "protocol": "TCP"}, {"containerPort": 443, "hostPort": 443, "protocol": "TCP"}]}]'
        
        echo -e "${GREEN}✓ Configuración de hostPort aplicada${NC}"
        ;;
        
    "microk8s")
        echo -e "\n${BLUE}2. Instalando NGINX Ingress Controller para MicroK8s...${NC}"
        
        # Para MicroK8s, usar el addon o configuración específica
        microk8s enable ingress 2>/dev/null || {
            # Si no está disponible el addon, usar manifest personalizado
            kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/controller-v1.9.4/deploy/static/provider/baremetal/deploy.yaml
            
            # Configurar NodePort para MicroK8s
            kubectl patch service ingress-nginx-controller -n ingress-nginx --type='json' \
                -p='[{"op": "replace", "path": "/spec/type", "value": "NodePort"}, {"op": "replace", "path": "/spec/ports/0/nodePort", "value": 30080}, {"op": "replace", "path": "/spec/ports/1/nodePort", "value": 30443}]'
        }
        ;;
        
    "kind")
        echo -e "\n${BLUE}2. Instalando NGINX Ingress Controller para Kind...${NC}"
        kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/controller-v1.9.4/deploy/static/provider/kind/deploy.yaml
        ;;
        
    "minikube")
        echo -e "\n${BLUE}2. Instalando NGINX Ingress Controller para Minikube...${NC}"
        minikube addons enable ingress 2>/dev/null || {
            kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/controller-v1.9.4/deploy/static/provider/baremetal/deploy.yaml
        }
        ;;
        
    *)
        echo -e "\n${BLUE}2. Instalando NGINX Ingress Controller para cluster en la nube...${NC}"
        
        # Verificar si Helm está disponible
        if command -v helm >/dev/null 2>&1; then
            echo -e "${BLUE}Usando Helm para la instalación...${NC}"
            helm repo add ingress-nginx https://kubernetes.github.io/ingress-nginx
            helm repo update
            helm install ingress-nginx ingress-nginx/ingress-nginx \
                --namespace ingress-nginx --create-namespace \
                --set controller.service.type=LoadBalancer
        else
            echo -e "${BLUE}Usando manifiestos YAML...${NC}"
            kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/controller-v1.9.4/deploy/static/provider/cloud/deploy.yaml
        fi
        ;;
esac

# Esperar a que los pods estén listos
echo -e "\n${BLUE}5. Esperando a que el ingress controller esté listo...${NC}"
wait_for_pods "ingress-nginx" 300

# Verificar instalación
echo -e "\n${BLUE}6. Verificando instalación...${NC}"
kubectl get pods -n ingress-nginx
kubectl get services -n ingress-nginx

# Mostrar información específica según el tipo de cluster
case $CLUSTER_TYPE in
    "docker-desktop")
        echo -e "\n${GREEN}✅ NGINX Ingress Controller instalado exitosamente para Docker Desktop${NC}"
        echo -e "${BLUE}Configuración:${NC}"
        echo -e "• Puerto HTTP: 80 (mapeado directamente vía hostPort)"
        echo -e "• Puerto HTTPS: 443 (mapeado directamente vía hostPort)"
        echo -e "• Acceso sin puerto específico: ✅"
        ;;
        
    "microk8s"|"minikube")
        echo -e "\n${GREEN}✅ NGINX Ingress Controller instalado exitosamente para $CLUSTER_TYPE${NC}"
        echo -e "${BLUE}Configuración:${NC}"
        echo -e "• Puerto HTTP: 30080 (NodePort)"
        echo -e "• Puerto HTTPS: 30443 (NodePort)"
        echo -e "• Acceso: http://tu-dominio:30080 y https://tu-dominio:30443"
        ;;
        
    "kind")
        echo -e "\n${GREEN}✅ NGINX Ingress Controller instalado exitosamente para Kind${NC}"
        echo -e "${BLUE}Configuración:${NC}"
        echo -e "• Puerto HTTP: 80 (configurado para Kind)"
        echo -e "• Puerto HTTPS: 443 (configurado para Kind)"
        ;;
        
    *)
        echo -e "\n${GREEN}✅ NGINX Ingress Controller instalado exitosamente${NC}"
        echo -e "${BLUE}Configuración:${NC}"
        echo -e "• Tipo: LoadBalancer (cloud)"
        echo -e "• Obteniendo IP externa..."
        
        # Intentar obtener la IP externa
        timeout=60
        while [ $timeout -gt 0 ]; do
            EXTERNAL_IP=$(kubectl get service -n ingress-nginx ingress-nginx-controller -o jsonpath='{.status.loadBalancer.ingress[0].ip}' 2>/dev/null)
            if [ -n "$EXTERNAL_IP" ] && [ "$EXTERNAL_IP" != "null" ]; then
                echo -e "${GREEN}• IP Externa: $EXTERNAL_IP${NC}"
                break
            fi
            sleep 5
            ((timeout-=5))
        done
        
        if [ -z "$EXTERNAL_IP" ] || [ "$EXTERNAL_IP" = "null" ]; then
            echo -e "${YELLOW}• IP Externa: Pendiente (puede tardar varios minutos)${NC}"
        fi
        ;;
esac

echo -e "\n${CYAN}🎉 Instalación completada${NC}"
echo -e "${BLUE}Comandos útiles:${NC}"
echo -e "• Ver pods: kubectl get pods -n ingress-nginx"
echo -e "• Ver servicios: kubectl get svc -n ingress-nginx"
echo -e "• Ver logs: kubectl logs -n ingress-nginx deployment/ingress-nginx-controller"