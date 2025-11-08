#!/bin/bash

# Script para construir y desplegar Backstage completo en Kubernetes

# Colores
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
CYAN='\033[0;36m'
NC='\033[0m'

echo -e "${CYAN}=== Construcción y Despliegue Completo de Backstage ===${NC}"
echo ""

# Verificar prerequisitos
echo -e "${BLUE}1. Verificando prerequisitos...${NC}"

# Docker
if ! docker ps >/dev/null 2>&1; then
    echo -e "${RED}❌ Docker no está funcionando${NC}"
    exit 1
fi

# Kubernetes
if ! kubectl cluster-info >/dev/null 2>&1; then
    echo -e "${RED}❌ No se puede conectar al cluster Kubernetes${NC}"
    exit 1
fi

echo -e "${GREEN}✓ Docker y Kubernetes funcionando${NC}"

# Opciones de despliegue
echo -e "\n${BLUE}¿Qué tipo de despliegue quieres realizar?${NC}"
echo "1) Desarrollo local (Docker Compose)"
echo "2) Desarrollo en Kubernetes (sin construir imagen)"
echo "3) Producción en Kubernetes (construir imagen completa)"
echo ""
read -p "Selecciona una opción (1-3): " choice

case $choice in
    1)
        echo -e "\n${BLUE}🐳 Iniciando desarrollo local con Docker Compose...${NC}"
        cd docker
        docker-compose up -d postgres redis
        echo -e "${GREEN}✅ Servicios iniciados. Ejecuta 'npm run dev' para Backstage${NC}"
        ;;
    2)
        echo -e "\n${BLUE}☸️ Desplegando infraestructura en Kubernetes...${NC}"
        cd kubernetes
        ./deploy.sh
        ;;
    3)
        echo -e "\n${BLUE}🏭 Construyendo imagen de producción...${NC}"
        
        # Verificar que tenemos los archivos necesarios
        if [ ! -f "package.json" ]; then
            echo -e "${RED}❌ Primero ejecuta el setup: ./setup-local.sh${NC}"
            exit 1
        fi
        
        # Construir imagen Docker
        echo -e "${BLUE}📦 Construyendo imagen Docker...${NC}"
        docker build -f Dockerfile.prod -t backstage:latest .
        
        if [ $? -eq 0 ]; then
            echo -e "${GREEN}✅ Imagen construida exitosamente${NC}"
            
            # Actualizar deployment para usar la imagen
            sed -i '' 's|# image: backstage:latest.*|image: backstage:latest|' kubernetes/backstage.yaml
            sed -i '' 's|image: node:18-alpine.*|image: backstage:latest|' kubernetes/backstage.yaml
            
            # Desplegar en Kubernetes
            echo -e "\n${BLUE}☸️ Desplegando en Kubernetes...${NC}"
            cd kubernetes
            ./deploy.sh
        else
            echo -e "${RED}❌ Error construyendo la imagen${NC}"
            exit 1
        fi
        ;;
    *)
        echo -e "${RED}❌ Opción inválida${NC}"
        exit 1
        ;;
esac

echo -e "\n${GREEN}🎉 ¡Despliegue completado!${NC}"