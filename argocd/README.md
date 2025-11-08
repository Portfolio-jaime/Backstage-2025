# ArgoCD con Ingress para Docker Desktop

Este directorio contiene los manifiestos para desplegar ArgoCD con NGINX Ingress Controller optimizado específicamente para Docker Desktop Kubernetes.

## Características

- ✅ Acceso sin puertos específicos (`http://argocd.test.com` y `https://argocd.test.com`)
- ✅ Configuración optimizada para Docker Desktop Kubernetes
- ✅ NGINX Ingress Controller con hostPort configurado
- ✅ ArgoCD en modo inseguro para compatibilidad con proxy reverso
- ✅ Scripts de instalación y verificación automatizados

## Componentes

- **namespace.yaml**: Namespace para ArgoCD
- **argocd-install.yaml**: Instalación de ArgoCD usando manifiestos oficiales
- **argocd-ingress.yaml**: Configuración de ingress para acceso HTTP/HTTPS
- **argocd-ingress-http.yaml**: Configuración final de ingress optimizada
- **install-ingress-controller.sh**: Script inteligente para instalar NGINX Ingress Controller
- **docker-desktop-ingress-patch.yaml**: Configuración específica para Docker Desktop
- **deploy.sh**: Script de despliegue automatizado completo
- **verify.sh**: Script de verificación completa del despliegue

## Instalación Rápida (Recomendada)

```bash
# Ejecutar script de despliegue completo
./deploy.sh

# Verificar instalación
./verify.sh
```

## Instalación Manual

1. Crear el namespace:
   ```bash
   kubectl apply -f namespace.yaml
   ```

2. Instalar ArgoCD:
   ```bash
   kubectl apply -f argocd-install.yaml
   ```

3. Instalar NGINX Ingress Controller:
   ```bash
   ./install-ingress-controller.sh
   ```

4. Configurar ArgoCD para modo inseguro:
   ```bash
   kubectl patch deployment argocd-server -n argocd --type='json' \
     -p='[{"op": "add", "path": "/spec/template/spec/containers/0/args/-", "value": "--insecure"}]'
   ```

5. Aplicar configuración de ingress:
   ```bash
   kubectl apply -f argocd-ingress-http.yaml
   ```

6. Verificar instalación:
   ```bash
   ./verify.sh
   ```

## Configuración de DNS Local

Añadir al archivo `/etc/hosts`:
```
127.0.0.1 argocd.test.com
```

## URLs de Acceso

- **HTTP**: `http://argocd.test.com` (sin puerto específico)
- **HTTPS**: `https://argocd.test.com` (sin puerto específico)

## Credenciales

- **Usuario**: `admin`
- **Password**: Obtener con el script de verificación o manualmente:
  ```bash
  kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d
  ```

## Solución de Problemas

### Verificación Completa
```bash
./verify.sh
```

### Verificar Estado de Pods
```bash
kubectl get pods -n argocd
kubectl get pods -n ingress-nginx
```

### Verificar Ingress
```bash
kubectl get ingress -n argocd
kubectl describe ingress -n argocd argocd-server-ingress
```

### Logs del Ingress Controller
```bash
kubectl logs -n ingress-nginx deployment/ingress-nginx-controller
```

### Test de Conectividad
```bash
curl -I http://argocd.test.com
curl -I -k https://argocd.test.com
```

## Notas Importantes

- Esta configuración está optimizada específicamente para **Docker Desktop Kubernetes**
- El ingress controller usa `hostPort` para mapear puertos 80 y 443 directamente
- ArgoCD se ejecuta en modo `--insecure` para permitir el proxy reverso del ingress
- El acceso funciona sin especificar puertos (estándar 80/443)
- Se requiere entrada en `/etc/hosts` para resolución DNS local

## Arquitectura

```
Internet/Browser → /etc/hosts (argocd.test.com → 127.0.0.1)
                ↓
Docker Desktop Kubernetes
                ↓
NGINX Ingress Controller (hostPort 80/443)
                ↓
ArgoCD Server Service (ClusterIP:80/443)
                ↓
ArgoCD Server Pod (--insecure, port 8080)
```

## Despliegue rápido

### Paso 1: Instalar Ingress Controller (si no lo tienes)

```bash
# Instalar NGINX Ingress Controller automáticamente
./install-ingress-controller.sh
```

### Paso 2: Desplegar ArgoCD

#### Opción 1: Script automatizado (recomendado)

```bash
# Hacer el script ejecutable
chmod +x deploy.sh

# Ejecutar el despliegue (detecta automáticamente si falta el ingress controller)
./deploy.sh
```

#### Opción 2: Despliegue manual

```bash
# 1. Instalar ingress controller si no existe
./install-ingress-controller.sh

# 2. Crear namespace
kubectl apply -f namespace.yaml

# 3. Instalar ArgoCD
kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml

# 4. Esperar a que los pods estén listos
kubectl wait --for=condition=Ready pods --all -n argocd --timeout=600s

# 5. Aplicar ingress
kubectl apply -f argocd-ingress.yaml

# 6. Obtener contraseña inicial
kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d
```

## Tipos de cluster soportados

El script `install-ingress-controller.sh` detecta automáticamente el tipo de cluster y configura el ingress controller apropiadamente:

- **☁️ Clusters en la nube** (EKS, GKE, AKS): Usa LoadBalancer
- **🏠 MicroK8s**: Usa NodePort con puertos específicos  
- **🐳 Kind**: Usa configuración específica para Kind
- **💻 Minikube**: Usa NodePort
- **📦 Clusters con Helm**: Instalación optimizada con Helm

### Para clusters locales (MicroK8s, Kind, Minikube):

El acceso será a través de NodePort. Ejemplo:
- HTTP: `http://argocd.test.com:30080`  
- HTTPS: `https://argocd.test.com:30443`

### Para clusters en la nube:

El acceso será a través de LoadBalancer:
- HTTPS: `https://argocd.test.com`

## Configuración del ingress

El archivo `argocd-ingress.yaml` está configurado para **NGINX Ingress Controller**. Si usas otro ingress controller:

### Para Traefik:
Descomenta y ajusta estas anotaciones en `argocd-ingress.yaml`:
```yaml
traefik.ingress.kubernetes.io/router.tls: "true"
traefik.ingress.kubernetes.io/router.entrypoints: websecure
```

### Para otros ingress controllers:
Ajusta las anotaciones según la documentación de tu ingress controller.

## Acceso a ArgoCD

### Configurar DNS local
Agrega esta línea a tu `/etc/hosts`:
```
<IP-DE-TU-CLUSTER> argocd.test.com
```

### Credenciales de acceso
- **URL**: https://argocd.test.com
- **Usuario**: admin
- **Contraseña**: (obtenida del script de despliegue)

### Acceso alternativo con port-forward
```bash
kubectl port-forward svc/argocd-server -n argocd 8080:443
```
Luego acceder a: https://localhost:8080

## Comandos útiles

```bash
# Ver estado de los pods
kubectl get pods -n argocd

# Ver estado del ingress
kubectl get ingress -n argocd

# Ver logs del servidor
kubectl logs -n argocd deployment/argocd-server

# Cambiar contraseña de admin
argocd account update-password

# Obtener contraseña inicial nuevamente
kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d
```

## Solución de problemas

### 1. Los pods no inician
```bash
kubectl describe pods -n argocd
kubectl logs -n argocd <pod-name>
```

### 2. Ingress no funciona
- Verificar que el ingress controller esté funcionando
- Revisar las anotaciones del ingress según tu controller
- Verificar la configuración DNS

### 3. Problemas de certificado TLS
```bash
# Recrear el secreto TLS
kubectl delete secret argocd-server-tls -n argocd
./deploy.sh  # Ejecutar nuevamente para recrear el certificado
```

## Configuraciones adicionales

### Para producción:
1. Configurar certificados TLS válidos (Let's Encrypt)
2. Configurar autenticación externa (OIDC, SAML)
3. Configurar RBAC personalizado
4. Configurar backup de la configuración

### Configurar Let's Encrypt con cert-manager:
```yaml
apiVersion: cert-manager.io/v1
kind: Certificate
metadata:
  name: argocd-tls
  namespace: argocd
spec:
  secretName: argocd-server-tls
  dnsNames:
  - argocd.test.com
  issuerRef:
    name: letsencrypt-prod
    kind: ClusterIssuer
```

## Recursos adicionales

- [Documentación oficial de ArgoCD](https://argo-cd.readthedocs.io/)
- [Configuración de ingress](https://argo-cd.readthedocs.io/en/stable/operator-manual/ingress/)
- [Configuración de autenticación](https://argo-cd.readthedocs.io/en/stable/operator-manual/user-management/)