#!/bin/bash

# Script de desarrollo rápido para Backstage

# Colores
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

echo -e "${BLUE}🚀 Iniciando Backstage en modo desarrollo...${NC}"

# Función para verificar si un puerto está en uso
check_port() {
    if lsof -Pi :$1 -sTCP:LISTEN -t >/dev/null ; then
        return 0
    else
        return 1
    fi
}

# Verificar prerequisitos
echo -e "${BLUE}🔍 Verificando prerequisitos...${NC}"

# Verificar Docker
if ! docker ps >/dev/null 2>&1; then
    echo -e "${RED}❌ Docker no está funcionando. Inicia Docker Desktop primero.${NC}"
    exit 1
fi

# Verificar Node.js
if ! command -v node >/dev/null 2>&1; then
    echo -e "${RED}❌ Node.js no encontrado. Instala Node.js 18+ primero.${NC}"
    exit 1
fi

# Verificar que estamos en el directorio correcto
if [ ! -f "package.json" ]; then
    echo -e "${RED}❌ No se encontró package.json. Ejecuta desde el directorio root del proyecto.${NC}"
    exit 1
fi

# Cambiar al directorio docker para manejar servicios
echo -e "${BLUE}📦 Iniciando servicios de base de datos...${NC}"
cd docker

# Crear archivo .env si no existe
if [ ! -f ".env" ]; then
    echo -e "${YELLOW}⚠️  Creando archivo .env desde template...${NC}"
    cp .env.example .env
fi

# Iniciar PostgreSQL y Redis
echo -e "${BLUE}🐘 Iniciando PostgreSQL...${NC}"
docker-compose up -d postgres redis

# Esperar a que PostgreSQL esté listo
echo -e "${YELLOW}⏳ Esperando a que PostgreSQL esté listo...${NC}"
timeout=60
while [ $timeout -gt 0 ]; do
    if docker-compose exec -T postgres pg_isready -U backstage -d backstage >/dev/null 2>&1; then
        echo -e "${GREEN}✅ PostgreSQL está listo${NC}"
        break
    fi
    echo -n "."
    sleep 2
    ((timeout-=2))
done

if [ $timeout -le 0 ]; then
    echo -e "${RED}❌ Timeout esperando PostgreSQL. Verifica los logs: docker-compose logs postgres${NC}"
    exit 1
fi

# Volver al directorio raíz
cd ..

# Verificar puertos
echo -e "${BLUE}🔍 Verificando puertos...${NC}"
if check_port 3000; then
    echo -e "${YELLOW}⚠️  Puerto 3000 en uso. Verifica: lsof -i :3000${NC}"
    exit 1
fi

if check_port 7007; then
    echo -e "${YELLOW}⚠️  Puerto 7007 en uso. Verifica: lsof -i :7007${NC}"
    exit 1
fi

# Instalar/actualizar dependencias si es necesario
if [ ! -d "node_modules" ] || [ "package.json" -nt "node_modules" ]; then
    echo -e "${BLUE}📦 Instalando/actualizando dependencias...${NC}"
    npm install
fi

# Verificar si existe la configuración de la app
if [ ! -f "configs/app-config.local.yaml" ]; then
    echo -e "${YELLOW}⚠️  Configuración no encontrada. Ejecuta './setup-local.sh' primero.${NC}"
    exit 1
fi

# Ejecutar migraciones de base de datos si es necesario
echo -e "${BLUE}🗄️  Verificando base de datos...${NC}"
if command -v yarn >/dev/null 2>&1; then
    yarn workspace backend backstage-cli migrations:create --config configs/app-config.local.yaml 2>/dev/null || true
else
    npx backstage-cli migrations:create --config configs/app-config.local.yaml 2>/dev/null || true
fi

echo -e "${GREEN}✅ Todo listo para iniciar Backstage${NC}"
echo ""
echo -e "${BLUE}🌐 URLs que estarán disponibles:${NC}"
echo -e "   • Frontend: ${GREEN}http://localhost:3000${NC}"
echo -e "   • Backend API: ${GREEN}http://localhost:7007${NC}"
echo -e "   • ArgoCD: ${GREEN}https://argocd.test.com${NC}"
echo -e "   • Base de datos: ${GREEN}postgresql://localhost:5432/backstage${NC}"
echo ""
echo -e "${YELLOW}💡 Usa Ctrl+C para detener el servidor${NC}"
echo -e "${YELLOW}💡 Los cambios se reflejan automáticamente (hot reload)${NC}"
echo ""

# Iniciar Backstage en modo desarrollo
echo -e "${BLUE}🎯 Iniciando Backstage...${NC}"

# Verificar si tenemos yarn instalado
if command -v yarn >/dev/null 2>&1; then
    echo -e "${BLUE}📦 Usando yarn...${NC}"
    yarn dev
else
    echo -e "${BLUE}📦 Usando npm...${NC}"
    npm run dev
fi