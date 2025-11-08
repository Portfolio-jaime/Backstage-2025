#!/bin/bash

# Colores para output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

echo -e "${CYAN}=== Setup de Backstage para Desarrollo Local ===${NC}"
echo ""

# Verificar prerequisitos
echo -e "${BLUE}1. Verificando prerequisitos...${NC}"

# Verificar Node.js
if command -v node >/dev/null 2>&1; then
    NODE_VERSION=$(node --version)
    echo -e "${GREEN}✓ Node.js encontrado: $NODE_VERSION${NC}"
    
    # Verificar versión mínima (18+)
    NODE_MAJOR=$(echo $NODE_VERSION | cut -d'.' -f1 | sed 's/v//')
    if [ "$NODE_MAJOR" -lt 18 ]; then
        echo -e "${RED}✗ Node.js versión 18+ requerida. Versión actual: $NODE_VERSION${NC}"
        exit 1
    fi
else
    echo -e "${RED}✗ Node.js no encontrado. Instala Node.js 18+ antes de continuar.${NC}"
    exit 1
fi

# Verificar npm
if command -v npm >/dev/null 2>&1; then
    NPM_VERSION=$(npm --version)
    echo -e "${GREEN}✓ npm encontrado: $NPM_VERSION${NC}"
else
    echo -e "${RED}✗ npm no encontrado${NC}"
    exit 1
fi

# Verificar Docker
if command -v docker >/dev/null 2>&1; then
    if docker ps >/dev/null 2>&1; then
        echo -e "${GREEN}✓ Docker funcionando${NC}"
    else
        echo -e "${RED}✗ Docker no está funcionando. Inicia Docker Desktop.${NC}"
        exit 1
    fi
else
    echo -e "${RED}✗ Docker no encontrado. Instala Docker Desktop.${NC}"
    exit 1
fi

# Verificar kubectl
if command -v kubectl >/dev/null 2>&1; then
    if kubectl cluster-info >/dev/null 2>&1; then
        echo -e "${GREEN}✓ kubectl configurado y conectado${NC}"
    else
        echo -e "${YELLOW}⚠ kubectl encontrado pero no conectado a un cluster${NC}"
    fi
else
    echo -e "${YELLOW}⚠ kubectl no encontrado (opcional para desarrollo)${NC}"
fi

# Verificar ArgoCD
echo -e "\n${BLUE}2. Verificando ArgoCD existente...${NC}"
if curl -k -s -o /dev/null -w "%{http_code}" https://argocd.test.com | grep -q "200\|307"; then
    echo -e "${GREEN}✓ ArgoCD accesible en https://argocd.test.com${NC}"
    
    # Obtener credenciales de ArgoCD
    ARGOCD_PASSWORD=$(kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" 2>/dev/null | base64 -d 2>/dev/null || echo "")
    if [ -n "$ARGOCD_PASSWORD" ]; then
        echo -e "${GREEN}✓ Credenciales de ArgoCD obtenidas${NC}"
    else
        echo -e "${YELLOW}⚠ No se pudieron obtener credenciales automáticamente${NC}"
    fi
else
    echo -e "${YELLOW}⚠ ArgoCD no accesible. Ejecuta primero el despliegue de ArgoCD.${NC}"
fi

# Crear estructura de directorios
echo -e "\n${BLUE}3. Creando estructura de proyecto...${NC}"

# Directorios principales
directories=(
    "docker"
    "packages/app/src"
    "packages/backend/src"
    "packages/common"
    "plugins/argocd"
    "plugins/kubernetes" 
    "plugins/tech-radar"
    "catalog/entities"
    "catalog/templates"
    "catalog/systems"
    "configs"
    "scripts"
)

for dir in "${directories[@]}"; do
    mkdir -p "$dir"
    echo -e "${GREEN}✓ Creado directorio: $dir${NC}"
done

# Crear archivo .env
echo -e "\n${BLUE}4. Configurando variables de entorno...${NC}"

cat > docker/.env << EOF
# Base de datos PostgreSQL
POSTGRES_USER=backstage
POSTGRES_PASSWORD=backstage123
POSTGRES_DB=backstage
POSTGRES_PORT=5432

# ArgoCD Integration
ARGOCD_URL=https://argocd.test.com
ARGOCD_USERNAME=admin
ARGOCD_PASSWORD=Thomas#1109

# Backstage
BACKSTAGE_PORT=3000
BACKSTAGE_BACKEND_PORT=7007

# GitHub (opcional - configura si tienes tokens)
GITHUB_TOKEN=
AUTH_GITHUB_CLIENT_ID=
AUTH_GITHUB_CLIENT_SECRET=

# Auth
AUTH_SECRET=your-secret-key-change-this-in-production

# Kubernetes (opcional)
KUBERNETES_SERVICE_ACCOUNT_TOKEN=

# Development
NODE_ENV=development
LOG_LEVEL=debug
EOF

echo -e "${GREEN}✓ Archivo .env creado en docker/.env${NC}"

# Verificar si Backstage CLI está instalado
echo -e "\n${BLUE}5. Verificando/Instalando Backstage CLI...${NC}"
if command -v backstage >/dev/null 2>&1; then
    echo -e "${GREEN}✓ Backstage CLI ya está instalado${NC}"
else
    echo -e "${YELLOW}⚠ Instalando Backstage CLI globalmente...${NC}"
    npm install -g @backstage/cli
    echo -e "${GREEN}✓ Backstage CLI instalado${NC}"
fi

# Crear proyecto Backstage si no existe
echo -e "\n${BLUE}6. Configurando proyecto Backstage...${NC}"
if [ ! -f "package.json" ]; then
    echo -e "${BLUE}Creando nuevo proyecto Backstage...${NC}"
    
    # Crear package.json base
    cat > package.json << 'EOF'
{
  "name": "backstage-dev",
  "version": "0.1.0",
  "private": true,
  "scripts": {
    "dev": "concurrently \"yarn start\" \"yarn start-backend\"",
    "start": "yarn workspace app start",
    "start-backend": "yarn workspace backend start",
    "build": "backstage-cli repo build --all",
    "build-image": "backstage-cli repo build-image",
    "tsc": "tsc",
    "tsc:full": "backstage-cli repo clean && yarn tsc",
    "clean": "backstage-cli repo clean",
    "test": "backstage-cli repo test",
    "test:all": "backstage-cli repo test --coverage",
    "lint": "backstage-cli repo lint --since origin/master",
    "lint:all": "backstage-cli repo lint",
    "prettier:check": "prettier --check .",
    "new": "backstage-cli new --scope @backstage-dev",
    "db:migrate": "yarn workspace backend backstage-cli migrations:create",
    "db:seed": "yarn workspace backend start --config ../../configs/app-config.dev.yaml"
  },
  "workspaces": {
    "packages": [
      "packages/*",
      "plugins/*"
    ]
  },
  "devDependencies": {
    "@backstage/cli": "^0.25.0",
    "@spotify/prettier-config": "^15.0.0",
    "concurrently": "^8.0.0",
    "lerna": "^7.0.0",
    "prettier": "^2.8.0",
    "typescript": "~4.9.0"
  },
  "prettier": "@spotify/prettier-config",
  "lint-staged": {
    "*.{js,jsx,ts,tsx,mjs,cjs}": [
      "eslint --fix",
      "prettier --write"
    ],
    "*.{json,md}": [
      "prettier --write"
    ]
  }
}
EOF
    echo -e "${GREEN}✓ package.json creado${NC}"
    
    # Instalar dependencias básicas
    echo -e "${BLUE}Instalando dependencias básicas...${NC}"
    npm install
    
else
    echo -e "${GREEN}✓ Proyecto Backstage ya existe${NC}"
fi

echo -e "\n${BLUE}7. Configurando servicios Docker...${NC}"

# Crear docker-compose.yml
cat > docker/docker-compose.yml << 'EOF'
version: '3.8'

services:
  postgres:
    image: postgres:15
    restart: unless-stopped
    environment:
      POSTGRES_USER: ${POSTGRES_USER:-backstage}
      POSTGRES_PASSWORD: ${POSTGRES_PASSWORD:-backstage123}
      POSTGRES_DB: ${POSTGRES_DB:-backstage}
    ports:
      - "5432:5432"
    volumes:
      - postgres_data:/var/lib/postgresql/data
      - ./init-scripts:/docker-entrypoint-initdb.d
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U ${POSTGRES_USER:-backstage}"]
      interval: 30s
      timeout: 10s
      retries: 3

  redis:
    image: redis:7-alpine
    restart: unless-stopped
    ports:
      - "6379:6379"
    volumes:
      - redis_data:/data
    healthcheck:
      test: ["CMD", "redis-cli", "ping"]
      interval: 30s
      timeout: 10s
      retries: 3

  # Opcional: Backstage en container para desarrollo
  backstage:
    build:
      context: ..
      dockerfile: docker/Dockerfile.dev
    ports:
      - "3000:3000"
      - "7007:7007"
    environment:
      - NODE_ENV=development
      - POSTGRES_HOST=postgres
      - POSTGRES_PORT=5432
      - POSTGRES_USER=${POSTGRES_USER:-backstage}
      - POSTGRES_PASSWORD=${POSTGRES_PASSWORD:-backstage123}
      - POSTGRES_DB=${POSTGRES_DB:-backstage}
      - REDIS_URL=redis://redis:6379
    depends_on:
      postgres:
        condition: service_healthy
      redis:
        condition: service_healthy
    volumes:
      - ../packages:/app/packages
      - ../plugins:/app/plugins
      - ../configs:/app/configs
      - ../catalog:/app/catalog
      - /app/node_modules
      - /app/packages/app/node_modules
      - /app/packages/backend/node_modules
    profiles:
      - dev-container

volumes:
  postgres_data:
  redis_data:
EOF

echo -e "${GREEN}✓ docker-compose.yml creado${NC}"

# Crear Dockerfile para desarrollo
cat > docker/Dockerfile.dev << 'EOF'
FROM node:18-alpine

WORKDIR /app

# Install dependencies first for better caching
COPY package*.json ./
COPY yarn.lock ./
RUN yarn install --frozen-lockfile

# Copy source code
COPY . .

# Build the application
RUN yarn build

# Expose ports
EXPOSE 3000 7007

# Default command
CMD ["yarn", "dev"]
EOF

echo -e "${GREEN}✓ Dockerfile.dev creado${NC}"

# Crear configuraciones de Backstage
echo -e "\n${BLUE}8. Creando configuraciones de Backstage...${NC}"

cat > configs/app-config.local.yaml << EOF
# Configuración para desarrollo local
app:
  title: Backstage Dev
  baseUrl: http://localhost:3000
  
organization:
  name: Mi Organización

backend:
  baseUrl: http://localhost:7007
  listen:
    port: 7007
  cors:
    origin: http://localhost:3000
    methods: [GET, HEAD, PATCH, POST, PUT, DELETE]
    credentials: true
  database:
    client: pg
    connection:
      host: \${POSTGRES_HOST:-localhost}
      port: \${POSTGRES_PORT:-5432}
      user: \${POSTGRES_USER:-backstage}
      password: \${POSTGRES_PASSWORD:-backstage123}
      database: \${POSTGRES_DB:-backstage}
    
integrations:
  github:
    - host: github.com
      token: \${GITHUB_TOKEN}

argocd:
  appLocatorMethods:
    - type: 'config'
      instances:
        - name: default
          url: \${ARGOCD_URL:-https://argocd.test.com}
          username: \${ARGOCD_USERNAME:-admin}
          password: \${ARGOCD_PASSWORD}

kubernetes:
  serviceLocatorMethod:
    type: 'multiTenant'
  clusterLocatorMethods:
    - type: 'config'
      clusters:
        - url: https://kubernetes.default.svc
          name: local
          authProvider: 'serviceAccount'
          skipTLSVerify: false
          skipMetricsLookup: false

auth:
  providers:
    guest:
      dangerouslyAllowOutsideDevelopment: true
    github:
      development:
        clientId: \${AUTH_GITHUB_CLIENT_ID}
        clientSecret: \${AUTH_GITHUB_CLIENT_SECRET}

catalog:
  locations:
    - type: file
      target: ../catalog/entities/all.yaml
    - type: file  
      target: ../catalog/systems/systems.yaml
    - type: file
      target: ../catalog/templates/templates.yaml

techdocs:
  builder: 'local'
  generator:
    runIn: 'local'
  publisher:
    type: 'local'
EOF

echo -e "${GREEN}✓ app-config.local.yaml creado${NC}"

# Crear entidades de catálogo de ejemplo
echo -e "\n${BLUE}9. Creando catálogo de ejemplo...${NC}"

mkdir -p catalog/entities catalog/systems catalog/templates

cat > catalog/entities/all.yaml << 'EOF'
apiVersion: backstage.io/v1alpha1
kind: Location
metadata:
  name: example-entities
  description: Una colección de entidades de ejemplo
spec:
  targets:
    - ./users.yaml
    - ./groups.yaml
    - ./components.yaml
    - ./resources.yaml
EOF

cat > catalog/entities/users.yaml << 'EOF'
apiVersion: backstage.io/v1alpha1
kind: User
metadata:
  name: guest
  description: Usuario invitado para desarrollo
spec:
  profile:
    displayName: Guest User
    email: guest@company.com
  memberOf: [dev-team]
EOF

cat > catalog/entities/groups.yaml << 'EOF'
apiVersion: backstage.io/v1alpha1
kind: Group
metadata:
  name: dev-team
  description: Equipo de desarrollo
spec:
  type: team
  children: []
EOF

cat > catalog/entities/components.yaml << 'EOF'
apiVersion: backstage.io/v1alpha1
kind: Component
metadata:
  name: example-service
  description: Un microservicio de ejemplo
  annotations:
    github.com/project-slug: example/example-service
    argocd/app-name: example-service
spec:
  type: service
  lifecycle: experimental
  owner: dev-team
  system: example-system
---
apiVersion: backstage.io/v1alpha1
kind: Component
metadata:
  name: example-website
  description: Un website frontend de ejemplo
  annotations:
    github.com/project-slug: example/example-website
spec:
  type: website
  lifecycle: experimental
  owner: dev-team
  system: example-system
EOF

echo -e "${GREEN}✓ Catálogo de ejemplo creado${NC}"

# Crear script de inicio rápido
cat > scripts/start-dev.sh << 'EOF'
#!/bin/bash

echo "🚀 Iniciando Backstage en modo desarrollo..."

# Verificar si Docker está corriendo
if ! docker ps >/dev/null 2>&1; then
    echo "❌ Docker no está funcionando. Inicia Docker Desktop primero."
    exit 1
fi

# Iniciar servicios de base de datos
echo "📦 Iniciando PostgreSQL y Redis..."
cd docker
docker-compose up -d postgres redis

# Esperar a que PostgreSQL esté listo
echo "⏳ Esperando a que PostgreSQL esté listo..."
until docker-compose exec postgres pg_isready -U backstage; do
  sleep 1
done

echo "✅ Base de datos lista"

# Volver al directorio raíz
cd ..

# Instalar dependencias si no están instaladas
if [ ! -d "node_modules" ]; then
    echo "📦 Instalando dependencias..."
    yarn install
fi

echo "🎯 Iniciando Backstage..."
echo "Frontend: http://localhost:3000"
echo "Backend: http://localhost:7007" 
echo ""

# Iniciar Backstage
yarn dev
EOF

chmod +x scripts/start-dev.sh
echo -e "${GREEN}✓ Script de inicio creado: scripts/start-dev.sh${NC}"

# Verificación final
echo -e "\n${CYAN}=== Setup Completado ===${NC}"
echo ""
echo -e "${GREEN}✅ Proyecto Backstage configurado exitosamente${NC}"
echo ""
echo -e "${BLUE}📁 Estructura creada:${NC}"
echo "   ├── docker/              (PostgreSQL, Redis)"
echo "   ├── packages/            (App & Backend)"  
echo "   ├── plugins/             (Plugins personalizados)"
echo "   ├── catalog/             (Catálogo de software)"
echo "   ├── configs/             (Configuraciones)"
echo "   └── scripts/             (Scripts de desarrollo)"
echo ""
echo -e "${BLUE}🚀 Para iniciar el desarrollo:${NC}"
echo ""
echo -e "${YELLOW}Opción 1: Script automatizado${NC}"
echo "   ./scripts/start-dev.sh"
echo ""
echo -e "${YELLOW}Opción 2: Manual${NC}"
echo "   1. cd docker && docker-compose up -d"
echo "   2. yarn install"
echo "   3. yarn dev"
echo ""
echo -e "${BLUE}📱 URLs de acceso:${NC}"
echo "   • Backstage: http://localhost:3000"
echo "   • Backend API: http://localhost:7007"
echo "   • ArgoCD: https://argocd.test.com"
echo ""

if [ -n "$ARGOCD_PASSWORD" ]; then
echo -e "${BLUE}🔑 Credenciales ArgoCD (ya integradas):${NC}"
echo "   • Usuario: admin"
echo "   • Password: $ARGOCD_PASSWORD"
echo ""
fi

echo -e "${YELLOW}💡 Notas importantes:${NC}"
echo "   • Edita docker/.env para personalizar configuración"
echo "   • Los cambios en código se reflejan automáticamente (hot reload)"
echo "   • PostgreSQL data persiste en Docker volumes"
echo "   • ArgoCD ya está integrado con tu instalación existente"
echo ""
echo -e "${GREEN}¡Listo para desarrollar! 🎉${NC}"