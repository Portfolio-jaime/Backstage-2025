#!/bin/bash

# Script personalizado para configurar Backstage con información específica
# Usuario Docker Hub: jaimehenao8126
# Repo GitHub: git@github.com:Portfolio-jaime/Backstage-2025.git

set -e

echo "🚀 Configurando Backstage CI/CD Pipeline para Portfolio-jaime"

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

# Variables predefinidas
GITHUB_USER="Portfolio-jaime"
REPO_NAME="Backstage-2025"
DOCKERHUB_USERNAME="jaimehenao8126"

print_status "Configuración detectada:"
echo "  - GitHub User: $GITHUB_USER"
echo "  - Repository: $REPO_NAME"
echo "  - Docker Hub: $DOCKERHUB_USERNAME"
echo ""

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

# Solicitar información de Docker Hub
echo ""
print_status "Configuración de Docker Hub:"
read -s -p "Token de acceso de Docker Hub para $DOCKERHUB_USERNAME: " DOCKERHUB_TOKEN
echo ""
echo ""

# Verificar que el repo existe
print_status "Verificando repositorio $GITHUB_USER/$REPO_NAME..."

if ! gh repo view $GITHUB_USER/$REPO_NAME &> /dev/null; then
    print_error "El repositorio $GITHUB_USER/$REPO_NAME no existe."
    print_status "Por favor crea el repositorio primero en GitHub"
    exit 1
else
    print_success "Repositorio encontrado!"
fi

# Configurar secretos de GitHub
print_status "Configurando secretos de GitHub..."

# Docker Hub secrets
gh secret set DOCKERHUB_USERNAME --body "$DOCKERHUB_USERNAME" --repo $GITHUB_USER/$REPO_NAME
gh secret set DOCKERHUB_TOKEN --body "$DOCKERHUB_TOKEN" --repo $GITHUB_USER/$REPO_NAME

print_success "Secretos de Docker Hub configurados"

# Verificar configuración actual
print_status "Verificando configuración actual..."

# Verificar que los archivos están correctamente configurados
if grep -q "jaimehenao8126" backstage/kubernetes/kustomization.yaml; then
    print_success "kustomization.yaml configurado correctamente"
else
    print_error "kustomization.yaml no está configurado correctamente"
fi

if grep -q "Portfolio-jaime/Backstage-2025" backstage/argocd/application.yaml; then
    print_success "ArgoCD application configurada correctamente"
else
    print_error "ArgoCD application no está configurada correctamente"
fi

# Configurar git remotes si no existe
print_status "Configurando repositorio Git..."

if ! git remote get-url origin &> /dev/null; then
    git remote add origin git@github.com:Portfolio-jaime/Backstage-2025.git
    print_success "Remote origin agregado"
else
    print_warning "Remote origin ya existe"
    # Verificar que apunta al repo correcto
    CURRENT_ORIGIN=$(git remote get-url origin)
    if [[ "$CURRENT_ORIGIN" == *"Portfolio-jaime/Backstage-2025"* ]]; then
        print_success "Remote origin apunta al repositorio correcto"
    else
        print_warning "Remote origin apunta a: $CURRENT_ORIGIN"
        read -p "¿Quieres actualizarlo? (y/N): " UPDATE_ORIGIN
        if [[ "$UPDATE_ORIGIN" =~ ^[Yy]$ ]]; then
            git remote set-url origin git@github.com:Portfolio-jaime/Backstage-2025.git
            print_success "Remote origin actualizado"
        fi
    fi
fi

# Verificar estado del repositorio
print_status "Verificando estado del repositorio..."

if [ -n "$(git status --porcelain)" ]; then
    print_warning "Hay cambios sin commit"
    git status --short
    echo ""
    read -p "¿Quieres hacer commit de estos cambios? (y/N): " COMMIT_CHANGES
    if [[ "$COMMIT_CHANGES" =~ ^[Yy]$ ]]; then
        git add .
        git commit -m "feat: configure CI/CD pipeline for Portfolio-jaime

- Update Docker Hub configuration for jaimehenao8126
- Configure ArgoCD for Portfolio-jaime/Backstage-2025
- Adjust GitHub Actions for repo structure
- Setup complete GitOps workflow"
        print_success "Cambios committeados"
    fi
else
    print_success "Repositorio está limpio"
fi

echo ""
print_status "🎉 Configuración completada!"
echo ""
print_warning "Próximos pasos:"
echo "1. git push origin main  # Para disparar el primer pipeline"
echo "2. cd backstage && ./setup-argocd.sh  # Para configurar ArgoCD"
echo "3. Ver GitHub Actions: https://github.com/Portfolio-jaime/Backstage-2025/actions"
echo "4. Ver ArgoCD: https://argocd.test.com"
echo ""
print_success "¡Tu pipeline CI/CD está listo para Portfolio-jaime! 🚀"

# Información adicional
echo ""
print_status "📋 Información del Pipeline:"
echo "  - Docker Registry: docker.io/jaimehenao8126/backstage"
echo "  - GitHub Actions: Habilitado en push a main"
echo "  - ArgoCD Sync: Automático desde GitHub"
echo "  - Kubernetes Namespace: backstage"
echo ""