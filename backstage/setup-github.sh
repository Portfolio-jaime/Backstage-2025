#!/bin/bash

# Script para configurar el repositorio GitHub y secretos necesarios
# Ejecutar después de crear el repo en GitHub

set -e

echo "🚀 Configurando Backstage CI/CD Pipeline"

# Colores para output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Función para imprimir con colores
print_status() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Verificar que GitHub CLI está instalado
if ! command -v gh &> /dev/null; then
    print_error "GitHub CLI (gh) no está instalado. Por favor instálalo primero:"
    echo "https://cli.github.com/"
    exit 1
fi

# Verificar autenticación con GitHub
if ! gh auth status &> /dev/null; then
    print_error "No estás autenticado con GitHub CLI. Ejecuta: gh auth login"
    exit 1
fi

# Obtener información del usuario
print_status "Obteniendo información de GitHub..."
GITHUB_USER=$(gh api user --jq '.login')
print_success "Usuario GitHub: $GITHUB_USER"

# Solicitar información de Docker Hub
echo ""
print_status "Configuración de Docker Hub:"
read -p "Nombre de usuario de Docker Hub: " DOCKERHUB_USERNAME
read -s -p "Token de acceso de Docker Hub: " DOCKERHUB_TOKEN
echo ""

# Crear repo si no existe
REPO_NAME="backstage-platform"
print_status "Verificando repositorio $REPO_NAME..."

if ! gh repo view $GITHUB_USER/$REPO_NAME &> /dev/null; then
    print_status "Creando repositorio $REPO_NAME..."
    gh repo create $REPO_NAME --public --description "Backstage Platform with ArgoCD GitOps"
    print_success "Repositorio creado exitosamente!"
else
    print_warning "El repositorio ya existe."
fi

# Configurar secretos de GitHub
print_status "Configurando secretos de GitHub..."

# Docker Hub secrets
gh secret set DOCKERHUB_USERNAME --body "$DOCKERHUB_USERNAME" --repo $GITHUB_USER/$REPO_NAME
gh secret set DOCKERHUB_TOKEN --body "$DOCKERHUB_TOKEN" --repo $GITHUB_USER/$REPO_NAME

print_success "Secretos de Docker Hub configurados"

# Actualizar archivos con el nombre de usuario correcto
print_status "Actualizando configuración con tu información..."

# Actualizar kustomization.yaml
sed -i.bak "s/YOUR_DOCKERHUB_USERNAME/$DOCKERHUB_USERNAME/g" kubernetes/kustomization.yaml
rm kubernetes/kustomization.yaml.bak

# Actualizar ArgoCD application
sed -i.bak "s/YOUR_GITHUB_USERNAME/$GITHUB_USER/g" argocd/application.yaml
rm argocd/application.yaml.bak

print_success "Archivos de configuración actualizados"

# Configurar git remotes
print_status "Configurando repositorio Git..."

if ! git remote get-url origin &> /dev/null; then
    git remote add origin https://github.com/$GITHUB_USER/$REPO_NAME.git
    print_success "Remote origin agregado"
else
    print_warning "Remote origin ya existe"
fi

# Crear .gitignore si no existe
if [ ! -f .gitignore ]; then
    cat > .gitignore << EOL
# Dependencies
node_modules/
/.pnp
.pnp.js

# Production
/build
/dist

# Environment variables
.env
.env.local
.env.development.local
.env.test.local
.env.production.local

# Logs
npm-debug.log*
yarn-debug.log*
yarn-error.log*
lerna-debug.log*

# OS generated files
.DS_Store
.DS_Store?
._*
.Spotlight-V100
.Trashes
ehthumbs.db
Thumbs.db

# IDE
.vscode/
.idea/
*.swp
*.swo

# Backstage
*-credentials.yaml
.backstage/
EOL
    print_success ".gitignore creado"
fi

# Crear README.md informativo
cat > README.md << EOL
# Backstage Platform

Plataforma Backstage con ArgoCD y GitOps completo.

## 🚀 Características

- **CI/CD automatizado** con GitHub Actions
- **GitOps** con ArgoCD
- **Docker** multi-stage builds con tags automáticos
- **Kubernetes** deployment automatizado
- **Integración ArgoCD** para gestión de aplicaciones

## 🏗️ Arquitectura

\`\`\`
GitHub (código) → GitHub Actions (build) → Docker Hub (imagen) → ArgoCD (deploy) → Kubernetes
\`\`\`

## 📦 Componentes

- **Frontend**: React con Backstage UI
- **Backend**: Node.js con plugins de ArgoCD
- **Base de datos**: PostgreSQL
- **Cache**: Redis
- **Orquestación**: Kubernetes
- **GitOps**: ArgoCD

## 🔧 Desarrollo Local

\`\`\`bash
# Instalar dependencias
yarn install

# Iniciar desarrollo
yarn start
\`\`\`

## 🚀 Deployment

Cada push a \`main\` dispara automáticamente:
1. Build de la aplicación
2. Tests
3. Build y push de imagen Docker
4. Actualización de manifests Kubernetes
5. Sync automático en ArgoCD

## 🛠️ Configuración

### Variables de entorno requeridas:
- \`POSTGRES_PASSWORD\`
- \`ARGOCD_USERNAME\`
- \`ARGOCD_PASSWORD\`

### GitHub Secrets configurados:
- \`DOCKERHUB_USERNAME\`
- \`DOCKERHUB_TOKEN\`

## 📝 Logs y Monitoring

Acceso a la aplicación:
- **Backstage**: https://backstage.test.com
- **ArgoCD**: https://argocd.test.com

EOL

print_success "README.md creado"

# Preparar primer commit
print_status "Preparando primer commit..."

git add .
git commit -m "feat: initial Backstage platform with ArgoCD GitOps

- Complete CI/CD pipeline with GitHub Actions
- Docker multi-stage build with commit-based tags
- Kubernetes manifests with Kustomize
- ArgoCD application for GitOps deployment
- Integration with ArgoCD for app management"

print_success "Commit preparado"

echo ""
print_status "🎉 Configuración completada!"
echo ""
print_warning "Próximos pasos:"
echo "1. git push origin main"
echo "2. Ir a GitHub Actions para ver el primer build"
echo "3. Aplicar la aplicación ArgoCD: kubectl apply -f argocd/application.yaml"
echo "4. Verificar sync en ArgoCD UI: https://argocd.test.com"
echo ""
print_success "¡Tu pipeline CI/CD está listo! 🚀"