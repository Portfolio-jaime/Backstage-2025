# 📋 Configuración Manual del Pipeline CI/CD

Como no tienes GitHub CLI instalado, aquí están los pasos para configurar manualmente:

## 🔧 Pasos de Configuración Manual

### 1. **Instalar GitHub CLI** (opcional pero recomendado)
```bash
# En macOS con Homebrew
brew install gh

# O descarga directamente desde:
# https://cli.github.com/
```

### 2. **Configurar Secrets en GitHub** (REQUERIDO)

Ve a tu repositorio: https://github.com/Portfolio-jaime/Backstage-2025

1. Ir a **Settings** → **Secrets and variables** → **Actions**
2. Hacer clic en **New repository secret**
3. Agregar estos secrets:

| Name | Value |
|------|-------|
| `DOCKERHUB_USERNAME` | `jaimehenao8126` |
| `DOCKERHUB_TOKEN` | `tu_token_de_docker_hub` |

**Para obtener tu Docker Hub Token:**
1. Ve a https://hub.docker.com/settings/security
2. Clic en **New Access Token**
3. Nombre: `Backstage-CI`
4. Permisos: **Read, Write, Delete**
5. Copia el token generado

### 3. **Verificar Configuración Actual**

✅ **Archivos ya configurados:**
- `backstage/kubernetes/kustomization.yaml` → Docker Hub: `jaimehenao8126/backstage`
- `backstage/argocd/application.yaml` → Repo: `Portfolio-jaime/Backstage-2025`
- `.github/workflows/build-and-deploy.yml` → Pipeline configurado

### 4. **Hacer Push al Repositorio**

```bash
cd /Users/jaime.henao/arheanja/Backstage-solutions/Backstage-2025

# Verificar remote
git remote -v

# Si no existe, agregar:
git remote add origin git@github.com:Portfolio-jaime/Backstage-2025.git

# Agregar cambios
git add .
git commit -m "feat: complete CI/CD setup for Backstage platform

- Configure Docker Hub for jaimehenao8126
- Setup GitHub Actions pipeline
- Configure ArgoCD for GitOps
- Add complete Kubernetes manifests"

# Push inicial
git push origin main
```

### 5. **Verificar Pipeline**

Después del push:
1. Ve a: https://github.com/Portfolio-jaime/Backstage-2025/actions
2. Verifica que se ejecute el workflow **"Build and Deploy Backstage"**
3. La primera ejecución debería:
   - ✅ Build la aplicación
   - ✅ Crear imagen Docker `jaimehenao8126/backstage:main-<sha>`
   - ✅ Subir a Docker Hub
   - ✅ Actualizar manifests

### 6. **Configurar ArgoCD**

```bash
cd /Users/jaime.henao/arheanja/Backstage-solutions/Backstage-2025/backstage
./setup-argocd.sh
```

## 🎯 Verificación de Funcionamiento

### **GitHub Actions** ✅
- URL: https://github.com/Portfolio-jaime/Backstage-2025/actions
- Trigger: Push a `main` con cambios en `backstage/`
- Output: Imagen en Docker Hub con tag `main-<commit-sha>`

### **Docker Hub** 🐳
- URL: https://hub.docker.com/r/jaimehenao8126/backstage
- Tags esperados: `latest`, `main-<sha>`

### **ArgoCD** 🔄
- URL: https://argocd.test.com
- App: `backstage`
- Sync: Automático desde GitHub

### **Kubernetes** ☸️
```bash
kubectl get pods -n backstage
kubectl get svc -n backstage
kubectl get ingress -n backstage
```

## 🚨 Troubleshooting

### Si el pipeline falla:
1. Verificar que los secrets están configurados
2. Verificar permisos de Docker Hub token
3. Revisar logs en GitHub Actions

### Si ArgoCD no sincroniza:
1. Verificar que el repo es público o ArgoCD tiene acceso
2. Verificar la URL del repo en `backstage/argocd/application.yaml`
3. Forzar sync manual en ArgoCD UI

### Si Kubernetes falla:
1. Verificar que la imagen existe en Docker Hub
2. Verificar que `imagePullPolicy` está en `IfNotPresent`
3. Revisar logs con `kubectl logs -n backstage deployment/backstage`

## ✅ Estado Actual

**Configuración completada:**
- ✅ Pipeline GitHub Actions
- ✅ Docker Hub configuration (jaimehenao8126)
- ✅ ArgoCD application configuration
- ✅ Kubernetes manifests
- ✅ GitOps workflow

**Pendiente de configurar:**
- 🔄 GitHub Secrets (manual)
- 🔄 Primera push al repositorio
- 🔄 ArgoCD application deployment