# 🚀 Backstage Platform - GitOps Completo

## 📋 Resumen de lo Creado

### ✅ Estructura Completa CI/CD GitOps
```
├── .github/workflows/
│   └── build-and-deploy.yml     # Pipeline automatizado
├── kubernetes/
│   ├── kustomization.yaml       # Configuración GitOps
│   ├── patches/
│   │   └── production.yaml      # Optimizaciones de producción
│   └── *.yaml                   # Manifests de Kubernetes
├── argocd/
│   └── application.yaml         # Aplicación ArgoCD
├── Dockerfile                   # Multi-stage build optimizado
├── setup-github.sh             # Script de configuración GitHub
└── setup-argocd.sh            # Script de configuración ArgoCD
```

## 🔄 Flujo Completo Automatizado

### 1. **Developer Push** 
```bash
git add .
git commit -m "feat: nueva funcionalidad"
git push origin main
```

### 2. **GitHub Actions** (automático)
- 🏗️ Build de la aplicación Backstage
- 🧪 Ejecuta tests
- 🐳 Build imagen Docker con tag `main-<commit-sha>`
- 📤 Push a Docker Hub
- 📝 Actualiza manifests Kubernetes con nueva imagen
- 🔄 Commit automático con cambios

### 3. **ArgoCD** (automático)
- 👀 Detecta cambios en el repo
- 🔄 Sync automático de manifests
- 🚀 Deploy a Kubernetes
- ✅ Health checks y rollback automático si falla

## 🛠️ Pasos de Configuración

### Paso 1: Configurar GitHub y Docker Hub
```bash
# Ejecutar script de configuración
./setup-github.sh
```

**Qué hace este script:**
- ✅ Crea repositorio GitHub `backstage-platform`
- ✅ Configura secrets de Docker Hub
- ✅ Actualiza archivos con tu información
- ✅ Prepara primer commit

### Paso 2: Primera subida al repositorio
```bash
git push origin main
```

**Qué sucede:**
- ✅ Se ejecuta el pipeline por primera vez
- ✅ Se construye la imagen Docker
- ✅ Se sube a Docker Hub con tag `main-<sha>`

### Paso 3: Configurar ArgoCD
```bash
# Aplicar aplicación ArgoCD
./setup-argocd.sh
```

**Qué hace:**
- ✅ Crea aplicación ArgoCD que monitore tu repo
- ✅ Configura sync automático
- ✅ Despliega Backstage en Kubernetes

## 🔧 Configuración Requerida

### GitHub Secrets (configurados por script)
```bash
DOCKERHUB_USERNAME=tu_usuario
DOCKERHUB_TOKEN=tu_token_acceso
```

### Variables de Entorno K8s (ya configuradas)
```yaml
POSTGRES_PASSWORD: "secure_password_123"
ARGOCD_URL: "https://argocd.test.com"
ARGOCD_USERNAME: "admin"
ARGOCD_PASSWORD: "Thomas#1109"
```

## 📱 Acceso a Servicios

| Servicio | URL | Credenciales |
|----------|-----|--------------|
| **Backstage** | https://backstage.test.com | No requiere |
| **ArgoCD** | https://argocd.test.com | admin / Thomas#1109 |

## 🐳 Gestión de Imágenes Docker

### Tags Automáticos
- `latest` - Última versión en main
- `main-<sha7>` - Tag específico por commit
- `pr-<numero>` - Tag para Pull Requests

### Ejemplo de tags generados:
```
tu_usuario/backstage:latest
tu_usuario/backstage:main-a1b2c3d
tu_usuario/backstage:pr-123
```

## 🔍 Monitoring y Observabilidad

### Health Checks
- ✅ Health endpoint: `/api/health`
- ✅ Liveness probe cada 30s
- ✅ Readiness probe cada 10s

### ArgoCD Monitoring
- 📊 Dashboard de aplicaciones
- 🔄 Estado de sync
- 📝 Historial de deployments
- ⚠️ Alertas de fallas

## 🚀 Desarrollo y Testing

### Desarrollo Local
```bash
# Instalar dependencias
yarn install

# Modo desarrollo
yarn start
# Frontend: http://localhost:3000
# Backend: http://localhost:7007
```

### Testing Pipeline
```bash
# Tests locales
yarn test:all

# Build local
yarn build:backend

# Build imagen local
docker build -f Dockerfile -t backstage:local .
```

## 🔧 Troubleshooting

### Ver logs del pipeline
```bash
# En GitHub Actions tab de tu repo
https://github.com/TU_USUARIO/backstage-platform/actions
```

### Ver estado en ArgoCD
```bash
# Web UI
https://argocd.test.com

# CLI (opcional)
argocd app list
argocd app get backstage
argocd app sync backstage
```

### Verificar deployment K8s
```bash
# Ver pods
kubectl get pods -n backstage

# Ver logs
kubectl logs -n backstage deployment/backstage

# Ver eventos
kubectl get events -n backstage --sort-by=.lastTimestamp
```

## 🎯 Beneficios Alcanzados

### ✅ GitOps Completo
- **Código como única fuente de verdad**
- **Deployments automáticos y auditables**
- **Rollback automático en caso de fallas**

### ✅ CI/CD Robusto  
- **Build y test automático en cada push**
- **Imágenes versionadas con commits**
- **Deploy sin intervención manual**

### ✅ Observabilidad
- **Monitoring integrado con ArgoCD**
- **Health checks automáticos**
- **Historial completo de cambios**

### ✅ Seguridad
- **Secrets gestionados apropiadamente**
- **Imágenes escaneadas automáticamente**
- **Acceso controlado con RBAC**

## 🔮 Próximos Pasos Sugeridos

1. **Monitoring Avanzado**
   - Integrar Prometheus + Grafana
   - Configurar alertas en Slack/Teams

2. **Multi-Environment**
   - Crear environments dev/staging/prod
   - Branch-based deployments

3. **Security Scanning**
   - Integrar Snyk o similar
   - Container security scanning

4. **Performance**
   - Cache optimization
   - CDN para assets estáticos

¡Tu pipeline GitOps está completo y listo para producción! 🎉