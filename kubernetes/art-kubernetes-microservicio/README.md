# Artefacto Kubernetes - Microservicio Base

## 1. Descripción General

Este artefacto es un **Helm Chart base** diseñado para el despliegue estandarizado de microservicios en **AWS EKS (Elastic Kubernetes Service)**. Proporciona una infraestructura completa y lista para producción que incluye todos los recursos de Kubernetes necesarios para ejecutar aplicaciones empresariales con alta disponibilidad, escalabilidad automática y seguridad.

### Propósito

- **Estandarización**: Proporciona una plantilla base reutilizable para cualquier microservicio
- **Automatización**: Scripts de renderizado y despliegue automático según ambiente (dev/staging/prod)
- **Flexibilidad**: Sistema de variables que permite personalización sin modificar templates
- **Integración con CI/CD**: Diseñado para integrarse con Azure DevOps Pipelines usando Library Groups
- **Seguridad**: Soporte para IRSA (AWS), mTLS, ServiceAccounts y PodDisruptionBudgets
- **Escalabilidad**: Auto-escalado horizontal basado en CPU/Memoria con HPA

### Características Principales

- **7 recursos de Kubernetes**: Deployment, Service, Ingress, ConfigMap, HPA, ServiceAccount, PDB
- **3 ambientes pre-configurados**: Desarrollo, Staging y Producción
- **Configuración flexible**: Sistema de override de variables con archivos `.env.*`
- **Scripts automatizados**: Renderizado de templates y despliegue con un solo comando
- **Compatibilidad multi-cloud**: AWS (IRSA) y Azure (Workload Identity)
- **Alta disponibilidad**: PodDisruptionBudget y múltiples réplicas
- **Observabilidad**: Health checks, readiness/liveness probes

---

## 2. Estructura del Repositorio

```
art-kubernetes-microservicio/
│
├── app/                                    # Configuración de la aplicación (mantenida por desarrollador)
│   └── application.yaml                    # Valores para ConfigMap (Spring Boot, variables de app)
│
├── k8s/                                    # Helm Chart (templates y valores base)
│   ├── templates/                          # Plantillas de Kubernetes
│   │   ├── configmap.yaml                  # ConfigMap con application.yaml
│   │   ├── deployment.yaml                 # Deployment con pods y containers
│   │   ├── hpa.yaml                        # HorizontalPodAutoscaler (auto-escalado)
│   │   ├── ingress.yaml                    # Ingress (exposición externa)
│   │   ├── pdb.yaml                        # PodDisruptionBudget (alta disponibilidad)
│   │   ├── service.yaml                    # Service (balanceo de carga interno)
│   │   └── serviceaccount.yaml             # ServiceAccount (IRSA/Azure Identity)
│   │
│   ├── Chart.yaml                          # Metadata del Helm Chart
│   └── values.yaml                         # Valores por defecto (estructura base en Git)
│
├── rendered-manifests_YYYYMMDD_HHMMSS/    # Manifiestos renderizados (generados por render-template.sh)
│   ├── all-manifests.yaml                  # Todos los manifiestos en un solo archivo
│   ├── deployment.yaml                     # Deployment renderizado
│   ├── service.yaml                        # Service renderizado
│   ├── ingress.yaml                        # Ingress renderizado
│   ├── configmap.yaml                      # ConfigMap renderizado
│   ├── horizontalpodautoscaler.yaml        # HPA renderizado
│   ├── serviceaccount.yaml                 # ServiceAccount renderizado
│   ├── poddisruptionbudget.yaml            # PDB renderizado
│   └── diff-with-defaults.txt              # Diferencias con values.yaml por defecto
│
├── rendered-manifests -> rendered-manifests_YYYYMMDD_HHMMSS  # Symlink al último render
│
├── .env.dev                                # Variables de DESARROLLO (simula Library Group)
├── .env.staging                            # Variables de STAGING (simula Library Group)
├── .env.prod                               # Variables de PRODUCCIÓN (simula Library Group)
│
├── deployment.sh                           # Script de despliegue automático a Kubernetes
├── render-template.sh                      # Script de renderizado de templates Helm
│
├── .gitignore                              # Archivos excluidos de Git
└── README.md                               # Este archivo (documentación principal)
```

### Descripción de Carpetas y Archivos Clave

| Archivo/Carpeta | Propósito | ¿En Git? |
|-----------------|-----------|----------|
| `app/application.yaml` | Configuración de la aplicación (Spring Boot, endpoints, features) | ✅ Sí |
| `k8s/templates/` | Plantillas Helm de recursos Kubernetes | ✅ Sí |
| `k8s/values.yaml` | Valores base y estructura del chart (defaults) | ✅ Sí |
| `.env.dev/staging/prod` | Variables específicas por ambiente (overrides) | ⚠️ Sí (ejemplos), No en producción real |
| `rendered-manifests_*/` | YAMLs finales renderizados listos para kubectl apply | ❌ No (generados) |
| `deployment.sh` | Script de despliegue con Helm | ✅ Sí |
| `render-template.sh` | Script de renderizado de templates | ✅ Sí |

---

## 3. Diagrama de Objetos de Kubernetes

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                          NAMESPACE: ns-app-{env}                            │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                             │
│  ┌─────────────────────┐                                                   │
│  │   INGRESS           │  ← Exposición externa (HTTP/HTTPS + TLS/mTLS)     │
│  │  (nginx/alb)        │    Host: app.example.com                          │
│  └──────────┬──────────┘    Path: /ficohsa → rewrite → /                   │
│             │                                                               │
│             │ Enruta tráfico                                                │
│             ↓                                                               │
│  ┌─────────────────────┐                                                   │
│  │   SERVICE           │  ← Balanceo de carga interno (ClusterIP)          │
│  │  (ClusterIP:80)     │    Selector: app=microservicio-app                │
│  └──────────┬──────────┘                                                   │
│             │                                                               │
│             │ Distribuye tráfico entre pods                                 │
│             ↓                                                               │
│  ┌──────────────────────────────────────────────────────────┐              │
│  │                    DEPLOYMENT                            │              │
│  │  ┌──────────┐  ┌──────────┐  ┌──────────┐  ┌──────────┐ │              │
│  │  │  POD 1   │  │  POD 2   │  │  POD 3   │  │  POD N   │ │              │
│  │  │          │  │          │  │          │  │          │ │              │
│  │  │ Container│  │ Container│  │ Container│  │ Container│ │              │
│  │  │  Image   │  │  Image   │  │  Image   │  │  Image   │ │              │
│  │  │          │  │          │  │          │  │          │ │              │
│  │  │ /config/ │  │ /config/ │  │ /config/ │  │ /config/ │ │              │
│  │  │   ↑      │  │   ↑      │  │   ↑      │  │   ↑      │ │              │
│  │  └───┼──────┘  └───┼──────┘  └───┼──────┘  └───┼──────┘ │              │
│  │      │             │             │             │         │              │
│  │      └─────────────┴─────────────┴─────────────┘         │              │
│  │                    Monta ConfigMap                        │              │
│  └──────────────────────────────────────────────────────────┘              │
│             ↑                                  ↑                            │
│             │                                  │                            │
│  ┌──────────┴──────────┐          ┌───────────┴──────────┐                 │
│  │   CONFIGMAP         │          │  SERVICEACCOUNT      │                 │
│  │  application.yaml   │          │   AWS IRSA           │                 │
│  │  (app config)       │          │   role-arn: xxx      │                 │
│  └─────────────────────┘          └──────────────────────┘                 │
│                                                                             │
│  ┌─────────────────────────────────────────────────────────┐               │
│  │   HPA (HorizontalPodAutoscaler)                         │               │
│  │   Min: 1-3  |  Max: 2-10  |  Target: CPU 70%, MEM 80%  │               │
│  │   ↓ Escala automáticamente el Deployment               │               │
│  └─────────────────────────────────────────────────────────┘               │
│                                                                             │
│  ┌─────────────────────────────────────────────────────────┐               │
│  │   PDB (PodDisruptionBudget)                             │               │
│  │   minAvailable: 1-2  (garantiza disponibilidad)         │               │
│  │   ↓ Protege pods durante mantenimientos del cluster     │               │
│  └─────────────────────────────────────────────────────────┘               │
│                                                                             │
└─────────────────────────────────────────────────────────────────────────────┘

FLUJO DE TRÁFICO:
1. Usuario → Ingress (TLS/mTLS) → Service → Pods (Deployment)
2. HPA monitorea métricas → Escala Deployment automáticamente
3. PDB protege disponibilidad durante actualizaciones/mantenimientos
4. ServiceAccount provee identidad AWS IAM a los pods
5. ConfigMap provee configuración de aplicación a los pods
```

---

## 4. Funcionamiento de Helm, Values y Scripts

### 4.1. ¿Qué es Helm?

**Helm** es el gestor de paquetes de Kubernetes. Funciona como "apt/yum para Kubernetes", permitiendo:
- **Templates**: Archivos YAML con variables `{{ .Values.xxx }}`
- **Values**: Archivo `values.yaml` con valores que reemplazan las variables
- **Charts**: Paquetes que contienen templates + values
- **Releases**: Instalaciones de un chart en el cluster

### 4.2. Estructura de Templates

Los templates en `k8s/templates/` son archivos YAML de Kubernetes con sintaxis de Go Template:

```yaml
# Ejemplo: k8s/templates/deployment.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: {{ .Values.appName }}-deployment
  namespace: {{ .Values.namespace }}
spec:
  replicas: {{ .Values.replicaCount }}
  template:
    spec:
      containers:
      - name: {{ .Values.appName }}
        image: {{ .Values.image.registry }}/{{ .Values.image.repository }}:{{ .Values.image.tag }}
        resources:
          requests:
            memory: {{ .Values.resources.requests.memory }}
            cpu: {{ .Values.resources.requests.cpu }}
```

### 4.3. Funcionamiento de values.yaml

El archivo `k8s/values.yaml` contiene la **estructura base** y **valores por defecto**:

```yaml
# k8s/values.yaml
appName: microservicio-app
namespace: ns-app-dev
replicaCount: 1

image:
  registry: docker.io
  repository: nginx
  tag: 1.25-alpine

resources:
  requests:
    memory: 128Mi
    cpu: 100m
```

**Características**:
- ✅ **En Git**: Sí, contiene estructura y defaults
- ✅ **Versionado**: Se versiona con el código
- ✅ **Base común**: Todos los ambientes heredan de aquí

### 4.4. Sistema de Override con Variables (.env)

Para simular **Azure DevOps Library Groups**, usamos archivos `.env.*` que **sobrescriben** los valores de `values.yaml`:

```bash
# .env.prod (simula Library Group "microservicio-prod")
NAMESPACE=ns-app-prod
REPLICA_COUNT=5
IMAGE_TAG=1.25-alpine
MEMORY_REQUEST=512Mi
CPU_REQUEST=500m
HPA_ENABLED=true
HPA_MIN_REPLICAS=3
HPA_MAX_REPLICAS=10
```

**Características**:
- ⚠️ **En Git**: Solo archivos ejemplo, NO valores reales de producción
- 🔒 **Seguridad**: Valores sensibles van en Azure DevOps Library Groups
- 🎯 **Por ambiente**: Un archivo por ambiente (dev/staging/prod)

### 4.5. Flujo de Renderizado

```
┌─────────────────┐
│  values.yaml    │  ← Valores base (estructura en Git)
│  (base)         │
└────────┬────────┘
         │
         │ MERGE ↓
         │
┌────────▼────────┐
│  .env.{env}     │  ← Variables de ambiente (overrides)
│  (overrides)    │
└────────┬────────┘
         │
         │ APLICA A ↓
         │
┌────────▼────────┐
│  templates/     │  ← Templates con {{ .Values.xxx }}
│  (*.yaml)       │
└────────┬────────┘
         │
         │ RENDERIZA ↓
         │
┌────────▼────────────────────┐
│  rendered-manifests/        │  ← YAMLs finales (sin variables)
│  (deployment.yaml, etc)     │
└─────────────────────────────┘
```

### 4.6. Equivalencia con Azure DevOps

| Componente Local | Azure DevOps Pipeline | Propósito |
|------------------|----------------------|-----------|
| `values.yaml` | Versionado en Git | Estructura base del chart |
| `.env.dev` | Library Group "microservicio-dev" | Variables de desarrollo |
| `.env.staging` | Library Group "microservicio-staging" | Variables de staging |
| `.env.prod` | Library Group "microservicio-prod" | Variables de producción |
| `render-template.sh` | `helm template` en pipeline | Renderiza templates |
| `deployment.sh` | `helm upgrade --install` en pipeline | Despliega a cluster |

En Azure DevOps, el pipeline ejecutaría:

```yaml
# azure-pipelines.yml (ejemplo)
steps:
- task: HelmDeploy@0
  inputs:
    command: upgrade
    chartType: FilePath
    chartPath: k8s/
    releaseName: microservicio-app
    namespace: $(NAMESPACE)
    overrideValues: |
      replicaCount=$(REPLICA_COUNT)
      image.tag=$(IMAGE_TAG)
      resources.requests.memory=$(MEMORY_REQUEST)
      # ... todas las variables del Library Group
```

---

### 4.7. Script: render-template.sh

#### Descripción

Script de **renderizado de templates Helm** sin desplegar al cluster. Genera manifiestos YAML finales listos para inspección o aplicación manual con `kubectl apply`.

#### Funcionamiento

1. **Lee** el archivo `.env.{ambiente}` especificado
2. **Carga** las variables de ambiente (export)
3. **Ejecuta** `helm template` con overrides dinámicos usando `--set`
4. **Genera** directorio `rendered-manifests_YYYYMMDD_HHMMSS/` con:
   - Manifiestos individuales por recurso (deployment.yaml, service.yaml, etc)
   - `all-manifests.yaml`: Todos los recursos en un archivo
   - `diff-with-defaults.txt`: Diferencias con values.yaml
5. **Crea** symlink `rendered-manifests` al último render
6. **Muestra** resumen de archivos generados

#### Uso

```bash
# Sintaxis
./render-template.sh --env {dev|staging|prod}

# Ejemplos
./render-template.sh --env dev       # Renderiza con .env.dev
./render-template.sh --env staging   # Renderiza con .env.staging
./render-template.sh --env prod      # Renderiza con .env.prod
```

#### Casos de uso

- ✅ **Validar templates**: Ver cómo quedan los manifiestos antes de desplegar
- ✅ **Debugging**: Identificar problemas de sintaxis o valores incorrectos
- ✅ **Auditoría**: Revisar configuración final por ambiente
- ✅ **CI/CD**: Integrar en pipeline para generar artefactos
- ✅ **Diff**: Comparar cambios entre ambientes

#### Salida

```bash
$ ./render-template.sh --env staging

===============================================
HELM TEMPLATE RENDERING
===============================================
Environment: staging
Loading variables from: .env.staging

✓ Rendering templates with helm...
✓ Splitting manifests by resource type...
✓ Creating symlink to latest render...

Generated files:
  rendered-manifests_20251021_231648/
    ├── all-manifests.yaml              (6.7 KB)
    ├── deployment.yaml                 (1.9 KB)
    ├── service.yaml                    (335 B)
    ├── ingress.yaml                    (847 B)
    ├── configmap.yaml                  (1.8 KB)
    ├── horizontalpodautoscaler.yaml    (1.1 KB)
    ├── serviceaccount.yaml             (428 B)
    ├── poddisruptionbudget.yaml        (297 B)
    └── diff-with-defaults.txt          (6.7 KB)

Symlink: rendered-manifests -> rendered-manifests_20251021_231648
```

---

### 4.8. Script: deployment.sh

#### Descripción

Script de **despliegue automático** a cluster Kubernetes usando Helm. Ejecuta `helm upgrade --install` con los overrides del ambiente especificado.

#### Funcionamiento

1. **Lee** el archivo `.env.{ambiente}` especificado
2. **Carga** las variables de ambiente (export)
3. **Valida** conectividad al cluster con `kubectl cluster-info`
4. **Crea** namespace si no existe
5. **Ejecuta** `helm upgrade --install` con:
   - Release name basado en appName
   - Namespace del ambiente
   - Overrides dinámicos con `--set` (todas las variables)
   - Timeout de 5 minutos
   - Modo `--atomic` (rollback automático si falla)
6. **Verifica** estado del despliegue
7. **Muestra** recursos desplegados

#### Uso

```bash
# Sintaxis
./deployment.sh --env {dev|staging|prod}

# Ejemplos
./deployment.sh --env dev       # Despliega a ns-app-dev
./deployment.sh --env staging   # Despliega a ns-app-staging
./deployment.sh --env prod      # Despliega a ns-app-prod
```

#### Casos de uso

- ✅ **Despliegue inicial**: Primera instalación del microservicio
- ✅ **Actualización**: Upgrade de versión de imagen o configuración
- ✅ **Rollback automático**: Si falla, revierte automáticamente (--atomic)
- ✅ **CI/CD**: Integrar en pipeline de Azure DevOps
- ✅ **Multi-ambiente**: Desplegar a diferentes ambientes con mismo código

#### Características de Seguridad

- **--atomic**: Rollback automático si el despliegue falla
- **--timeout 5m**: Evita despliegues colgados
- **Validación previa**: Verifica conexión al cluster antes de desplegar
- **Namespace isolation**: Crea namespace dedicado por ambiente

#### Salida

```bash
$ ./deployment.sh --env staging

===============================================
KUBERNETES DEPLOYMENT WITH HELM
===============================================
Environment: staging
Loading variables from: .env.staging

✓ Cluster reachable
✓ Namespace ns-app-staging ready
✓ Deploying with Helm...

Release "microservicio-app" has been upgraded. Happy Helming!
NAME: microservicio-app
LAST DEPLOYED: Mon Oct 21 23:30:15 2024
NAMESPACE: ns-app-staging
STATUS: deployed
REVISION: 3

Deployed resources:
NAME                                           READY   STATUS    RESTARTS   AGE
pod/microservicio-app-deployment-5d8c7b4f-abc  1/1     Running   0          30s
pod/microservicio-app-deployment-5d8c7b4f-def  1/1     Running   0          30s

NAME                               TYPE        CLUSTER-IP      EXTERNAL-IP   PORT(S)
service/microservicio-app-service  ClusterIP   10.100.123.45   <none>        80/TCP

NAME                                       READY   UP-TO-DATE   AVAILABLE   AGE
deployment.apps/microservicio-app-deployment  2/2     2            2           30s

NAME                                                  REFERENCE                                 TARGETS
horizontalpodautoscaler.autoscaling/microservicio-app-hpa  Deployment/microservicio-app-deployment  cpu: 5%/70%, memory: 10%/80%
```

---

### 4.9. Diferencias entre render-template.sh y deployment.sh

| Característica | render-template.sh | deployment.sh |
|----------------|-------------------|---------------|
| **Acción** | Renderiza templates (no despliega) | Despliega al cluster |
| **Comando Helm** | `helm template` | `helm upgrade --install` |
| **Modifica cluster** | ❌ No | ✅ Sí |
| **Crea archivos** | ✅ Sí (rendered-manifests/) | ❌ No |
| **Requiere cluster** | ❌ No | ✅ Sí |
| **Uso típico** | Validación, debugging, CI/CD artifacts | Despliegue real a ambientes |
| **Rollback** | N/A | ✅ Sí (--atomic) |
| **Timeout** | N/A | ✅ Sí (5 minutos) |

**Recomendación**: Ejecutar primero `render-template.sh` para validar, luego `deployment.sh` para desplegar.

---

## 5. Objetos de Kubernetes

### 5.1. Deployment

#### Descripción

El **Deployment** es el recurso principal que gestiona los **Pods** (contenedores) de la aplicación. Se encarga de:
- Crear y mantener el número deseado de réplicas (pods)
- Actualizar la aplicación con rolling updates (sin downtime)
- Realizar rollbacks si hay problemas
- Gestionar health checks (liveness/readiness probes)
- Montar ConfigMaps y Secrets como volúmenes

**Nombre del recurso**: `{{ .Values.appName }}-deployment`
**Ejemplo**: `microservicio-app-deployment`

#### Variables de Configuración

| Variable | Valores Posibles | Dependencias | Observaciones |
|----------|------------------|--------------|---------------|
| `NAMESPACE` | Cualquier string (ej: `ns-app-dev`) | Ninguna | Namespace donde se despliega el deployment |
| `REPLICA_COUNT` | Entero >= 1 (ej: `1`, `3`, `5`) | Si `HPA_ENABLED=true`, HPA controla réplicas | Dev: 1, Staging: 2, Prod: 3-5 |
| `IMAGE_REGISTRY` | URL de registry (ej: `docker.io`, `123.dkr.ecr.us-east-1.amazonaws.com`) | Ninguna | Registro de imágenes Docker |
| `IMAGE_REPOSITORY` | Nombre de imagen (ej: `nginx`, `my-app`) | Ninguna | Nombre del repositorio de la imagen |
| `IMAGE_TAG` | Tag de imagen (ej: `1.25-alpine`, `v1.0.0`) | Ninguna | **NO usar `latest` en producción** |
| `IMAGE_PULL_POLICY` | `Always`, `IfNotPresent`, `Never` | Ninguna | Prod: `Always`, Dev: `IfNotPresent` |
| `MEMORY_REQUEST` | Formato K8s (ej: `128Mi`, `1Gi`) | Debe ser <= `MEMORY_LIMIT` | Memoria mínima garantizada |
| `CPU_REQUEST` | Formato K8s (ej: `100m`, `1000m` = 1 CPU) | Debe ser <= `CPU_LIMIT` | CPU mínima garantizada |
| `MEMORY_LIMIT` | Formato K8s (ej: `256Mi`, `2Gi`) | Debe ser >= `MEMORY_REQUEST` | Memoria máxima permitida |
| `CPU_LIMIT` | Formato K8s (ej: `200m`, `2000m` = 2 CPUs) | Debe ser >= `CPU_REQUEST` | CPU máxima permitida |
| `CONTAINER_PORT` | Puerto (ej: `8080`, `3000`) | Debe coincidir con puerto de la app | Puerto donde escucha la aplicación |
| `LIVENESS_PROBE_PATH` | Path HTTP (ej: `/health`, `/actuator/health`) | App debe exponer endpoint | Health check para reiniciar pod |
| `READINESS_PROBE_PATH` | Path HTTP (ej: `/ready`, `/actuator/health/readiness`) | App debe exponer endpoint | Health check para recibir tráfico |
| `SERVICEACCOUNT_ENABLED` | `true`, `false` | Si true, requiere ServiceAccount creado | Habilita uso de ServiceAccount |

#### Consideraciones y Dependencias

**Recursos (requests vs limits)**:
- `requests`: Recursos **garantizados** por el scheduler de K8s
- `limits`: Recursos **máximos** permitidos antes de throttling (CPU) o kill (memoria)
- **Regla**: `requests <= limits`
- **OOMKilled**: Si el pod supera `MEMORY_LIMIT`, K8s lo mata y reinicia

**Health Checks**:
- **livenessProbe**: Detecta pods "zombies" (no responden) y los reinicia
- **readinessProbe**: Determina si el pod puede recibir tráfico (Service lo incluye/excluye)
- **Recomendación**: Configurar `initialDelaySeconds` según tiempo de startup de la app

**Interacción con HPA**:
- Si `HPA_ENABLED=true`, **NO MODIFICAR manualmente** `REPLICA_COUNT` en runtime
- HPA sobrescribe `replicaCount` dinámicamente basado en métricas
- Al deshabilitar HPA, el deployment vuelve al valor de `REPLICA_COUNT`

**Interacción con ConfigMap**:
- Si `CONFIGMAP_ENABLED=true`, el deployment monta `app/application.yaml` en `/app/config/application.yaml`
- Spring Boot lee automáticamente desde `/app/config/` (precedencia sobre JAR interno)

**Interacción con ServiceAccount**:
- Si `SERVICEACCOUNT_ENABLED=true`, los pods usan el ServiceAccount `{{ .Values.appName }}-sa`
- Esto permite asumir roles de AWS IAM (IRSA) o Azure Managed Identity sin credenciales

**Rolling Update**:
- Estrategia: `RollingUpdate` (default)
- `maxUnavailable: 25%`: Máximo 25% de pods down durante update
- `maxSurge: 25%`: Máximo 25% de pods extra durante update
- **Zero downtime**: Siempre hay pods corriendo durante actualizaciones

---

### 5.2. Service

#### Descripción

El **Service** es el balanceador de carga **interno** de Kubernetes. Proporciona:
- **IP estable** (ClusterIP) para acceder a los pods del Deployment
- **Balanceo de carga** automático entre réplicas
- **Service discovery** (DNS interno: `microservicio-app-service.ns-app-dev.svc.cluster.local`)
- **Health-aware routing**: Solo envía tráfico a pods con readinessProbe OK

**Nombre del recurso**: `{{ .Values.appName }}-service`
**Ejemplo**: `microservicio-app-service`

#### Variables de Configuración

| Variable | Valores Posibles | Dependencias | Observaciones |
|----------|------------------|--------------|---------------|
| `NAMESPACE` | Cualquier string | Debe coincidir con Deployment | Namespace donde se crea el Service |
| `SERVICE_PORT` | Puerto (ej: `80`, `443`, `8080`) | Ninguna | Puerto expuesto por el Service (frontend) |
| `CONTAINER_PORT` | Puerto (ej: `8080`, `3000`) | Debe coincidir con Deployment | Puerto del contenedor (backend) |
| `SERVICE_TYPE` | `ClusterIP`, `NodePort`, `LoadBalancer` | Ninguna | **ClusterIP** (default, interno), NodePort (dev), LoadBalancer (cloud) |

#### Consideraciones y Dependencias

**Tipo de Service**:
- **ClusterIP** (default): Solo accesible dentro del cluster
  - Uso: Comunicación interna entre microservicios
  - Exposición externa: A través de Ingress
- **NodePort**: Abre puerto en cada nodo del cluster (30000-32767)
  - Uso: Dev/testing sin Ingress
  - **NO recomendado en producción**
- **LoadBalancer**: Crea ELB/NLB en AWS (costo adicional)
  - Uso: Exposición directa sin Ingress (API Gateway, gRPC)
  - **Cuidado**: Crea recursos en la nube ($)

**Selector**:
```yaml
selector:
  app: {{ .Values.appName }}
```
- El Service encuentra pods con label `app=microservicio-app`
- **Importante**: Debe coincidir con labels del Deployment

**Service Discovery**:
- DNS interno: `<service-name>.<namespace>.svc.cluster.local`
- Ejemplo: `microservicio-app-service.ns-app-dev.svc.cluster.local`
- Desde mismo namespace: `microservicio-app-service`

**Interacción con Ingress**:
- El Ingress enruta tráfico externo **→ Service → Pods**
- El Service es el "backend" del Ingress

**Interacción con HPA**:
- El Service balancea automáticamente entre N réplicas (escaladas por HPA)
- No requiere configuración adicional al escalar

---

### 5.3. Ingress

#### Descripción

El **Ingress** es el punto de entrada **externo** al cluster. Funciona como un reverse proxy inteligente que:
- Enruta tráfico HTTP/HTTPS desde internet hacia Services internos
- Gestiona SSL/TLS termination (HTTPS)
- Implementa mTLS (mutual TLS) para autenticación de clientes
- Permite routing basado en host (`app.example.com`) y/o path (`/api/v1`)
- Reescribe URLs antes de enviarlas al Service backend

**Nombre del recurso**: `{{ .Values.appName }}-ingress`
**Ejemplo**: `microservicio-app-ingress`

#### Variables de Configuración

| Variable | Valores Posibles | Dependencias | Observaciones |
|----------|------------------|--------------|---------------|
| `INGRESS_ENABLED` | `true`, `false` | Requiere Ingress Controller instalado | Dev: opcional, Staging/Prod: true |
| `INGRESS_CLASS_NAME` | `nginx`, `alb` | Debe existir IngressClass en cluster | `nginx`: Nginx Ingress, `alb`: AWS ALB Controller |
| `INGRESS_HOST` | Dominio o vacío (ej: `app.example.com`, ``) | Si vacío: catch-all (acepta cualquier host) | **Vacío**: Útil para acceso por IP LoadBalancer |
| `INGRESS_PATH` | Path (ej: `/`, `/api`, `/ficohsa`) | Ninguna | Path que matchea la URL entrante |
| `INGRESS_REWRITE_TARGET` | Path o vacío (ej: `/`, `/v2`, ``) | Solo con `nginx` IngressClass | **Nginx**: Reescribe path antes de enviar a Service |
| `INGRESS_TLS_ENABLED` | `true`, `false` | Requiere `INGRESS_TLS_SECRET_NAME` creado | Habilita HTTPS (TLS termination) |
| `INGRESS_TLS_HOSTS` | Lista de dominios (ej: `app.example.com`) | Debe coincidir con `INGRESS_HOST` | Hosts cubiertos por el certificado TLS |
| `INGRESS_TLS_SECRET_NAME` | Nombre de Secret (ej: `app-prod-tls-secret`) | Secret tipo `kubernetes.io/tls` debe existir | Contiene `tls.crt` y `tls.key` |
| `INGRESS_MTLS_ENABLED` | `true`, `false` | Requiere `INGRESS_MTLS_SECRET_NAME` + TLS | Habilita mutual TLS (cliente también autentica) |
| `INGRESS_MTLS_SECRET_NAME` | Nombre de Secret (ej: `app-prod-mtls-client-secret`) | Secret con `ca.crt` (CA de clientes) | Certificado CA para validar clientes |
| `INGRESS_MTLS_VERIFY_CLIENT` | `on`, `off`, `optional` | Solo con `INGRESS_MTLS_ENABLED=true` | `on`: obliga mTLS, `optional`: permite sin cert |

#### Consideraciones y Dependencias

**Host: Específico vs Catch-All**:

```bash
# Opción 1: Host específico (solo acepta ese dominio)
INGRESS_HOST=app.example.com
# Acceso: http://app.example.com/ficohsa

# Opción 2: Sin host (acepta CUALQUIER IP/dominio - catch-all)
INGRESS_HOST=
# Acceso: http://<IP-LoadBalancer>/ficohsa
# Acceso: http://cualquier-dominio.com/ficohsa
```

**Path Rewrite (Nginx)**:

```yaml
# Configuración típica en .env
INGRESS_PATH=/ficohsa
INGRESS_REWRITE_TARGET=/

# Resultado:
# Usuario accede a: http://app.example.com/ficohsa/index.html
# Nginx reescribe a: http://microservicio-app-service/index.html
# (Elimina /ficohsa antes de enviar al Service)
```

**Annotations importantes (Nginx)**:
```yaml
annotations:
  nginx.ingress.kubernetes.io/rewrite-target: {{ .Values.ingress.rewriteTarget }}
  nginx.ingress.kubernetes.io/ssl-redirect: "true"  # Fuerza HTTPS
  nginx.ingress.kubernetes.io/auth-tls-verify-client: {{ .Values.ingress.mtls.verifyClient }}
```

**TLS/SSL**:
- Requiere Secret tipo `kubernetes.io/tls` con:
  - `tls.crt`: Certificado SSL
  - `tls.key`: Private key
- Crear Secret manualmente:
```bash
kubectl create secret tls app-prod-tls-secret \
  --cert=path/to/tls.crt \
  --key=path/to/tls.key \
  -n ns-app-prod
```

**mTLS (Mutual TLS)**:
- Autenticación bidireccional: Servidor valida cliente, cliente valida servidor
- Requiere:
  1. TLS habilitado (`INGRESS_TLS_ENABLED=true`)
  2. Secret con CA de clientes (`ca.crt`)
  3. Clientes con certificados firmados por esa CA
- Uso típico: APIs internas, B2B, microservicios de alta seguridad

**Dependencias**:
- **Ingress Controller**: Debe estar instalado en el cluster (nginx-ingress, ALB controller)
- **LoadBalancer**: Ingress Controller expone un Service tipo LoadBalancer (ELB/NLB en AWS)
- **DNS**: Dominio (`INGRESS_HOST`) debe apuntar a la IP del LoadBalancer

**Interacción con Service**:
```yaml
# Ingress backend apunta al Service
backend:
  service:
    name: microservicio-app-service
    port:
      number: {{ .Values.service.port }}
```

**Troubleshooting**:
- `404 Not Found`: Path no matchea o Service no existe
- `503 Service Unavailable`: Service existe pero no hay pods READY
- `Connection refused`: Ingress Controller no instalado o sin LoadBalancer

---

### 5.4. ConfigMap

#### Descripción

El **ConfigMap** almacena la **configuración de la aplicación** (variables, archivos de configuración) de forma separada del código. En este artefacto, gestiona el archivo `app/application.yaml` que contiene la configuración de Spring Boot (datasources, endpoints, logging, etc).

**Nombre del recurso**: `{{ .Values.appName }}-config`
**Ejemplo**: `microservicio-app-config`

**Particularidad clave**: El contenido del ConfigMap proviene de `app/application.yaml`, **NO de variables de .env**. Este archivo es mantenido por el desarrollador y contiene toda la configuración de la aplicación.

#### Variables de Configuración

| Variable | Valores Posibles | Dependencias | Observaciones |
|----------|------------------|--------------|---------------|
| `CONFIGMAP_ENABLED` | `true`, `false` | Requiere `app/application.yaml` | Habilita creación del ConfigMap |
| `NAMESPACE` | Cualquier string | Debe coincidir con Deployment | Namespace donde se crea el ConfigMap |

#### Estructura del ConfigMap

El ConfigMap se genera a partir de `app/application.yaml`:

```yaml
# app/application.yaml (mantenido por desarrollador)
application:
  server:
    port: 8080
  spring:
    datasource:
      url: "jdbc:postgresql://db-dev.internal:5432/myapp_dev"
      username: "myapp_user"
  logging:
    level:
      root: "DEBUG"
  api:
    external:
      auth:
        url: "http://auth-service-dev.internal/api/v1"
```

Se convierte en ConfigMap:

```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: microservicio-app-config
  namespace: ns-app-dev
data:
  application.yaml: |
    application:
      server:
        port: 8080
      spring:
        datasource:
          url: "jdbc:postgresql://db-dev.internal:5432/myapp_dev"
      ...
```

#### Montaje en Pods

El Deployment monta el ConfigMap como archivo:

```yaml
# Dentro del Deployment
volumeMounts:
- name: config-volume
  mountPath: /app/config
  readOnly: true

volumes:
- name: config-volume
  configMap:
    name: microservicio-app-config
```

**Resultado**: Archivo disponible en `/app/config/application.yaml` dentro del contenedor.

#### Consideraciones y Dependencias

**Diferencia con values.yaml**:
- `values.yaml`: Configuración de **Kubernetes** (réplicas, recursos, imagen)
- `application.yaml`: Configuración de la **aplicación** (Spring Boot, endpoints, logging)

**Separación de responsabilidades**:
- **Desarrollador**: Mantiene `app/application.yaml` (configuración de la app)
- **DevOps/CloudOps**: Mantiene `values.yaml` y `.env.*` (configuración de K8s)

**Override por ambiente**:
Para valores específicos por ambiente en `application.yaml`, hay 3 opciones:

**Opción 1**: Usar `--set` en el deployment script (recomendado para valores dinámicos):
```bash
# En Azure DevOps Pipeline
helm upgrade --install ... \
  --set application.spring.datasource.url="jdbc:postgresql://db-prod.internal:5432/myapp_prod" \
  --set application.logging.level.root="INFO"
```

**Opción 2**: Crear archivos por ambiente:
```
app/
  ├── application.yaml          # Base común
  ├── application-dev.yaml      # Overrides de dev
  ├── application-staging.yaml  # Overrides de staging
  └── application-prod.yaml     # Overrides de prod
```

**Opción 3**: Usar Spring Profiles:
```yaml
# application.yaml
spring:
  profiles:
    active: dev  # Cambia a staging/prod según ambiente

---
spring:
  config:
    activate:
      on-profile: dev
  datasource:
    url: "jdbc:postgresql://db-dev.internal:5432/myapp_dev"

---
spring:
  config:
    activate:
      on-profile: prod
  datasource:
    url: "jdbc:postgresql://db-prod.internal:5432/myapp_prod"
```

**Interacción con Secrets**:
- **NO almacenar passwords en ConfigMap** (visible en base64)
- Usar Secrets de Kubernetes para datos sensibles:
```bash
kubectl create secret generic db-credentials \
  --from-literal=password='mySecretPassword123' \
  -n ns-app-prod
```

**Hot-reload de configuración**:
- Por defecto, cambios en ConfigMap **NO actualizan** pods automáticamente
- Opciones:
  1. Recrear pods: `kubectl rollout restart deployment/microservicio-app-deployment`
  2. Usar herramientas como Reloader (stakater/reloader)
  3. Configurar app para recargar configuración (Spring Cloud Config)

**Límites**:
- Tamaño máximo ConfigMap: **1 MB**
- Para archivos grandes (>1MB): Usar volúmenes persistentes o S3

---

### 5.5. HPA (HorizontalPodAutoscaler)

#### Descripción

El **HPA** escala automáticamente el número de réplicas del Deployment basándose en métricas de uso (CPU, memoria). Garantiza:
- **Escalado automático UP**: Cuando CPU/Memoria superan el objetivo, crea más pods
- **Escalado automático DOWN**: Cuando baja el uso, reduce pods (ahorra recursos)
- **Respuesta a picos de tráfico**: Mantiene performance sin intervención manual
- **Optimización de costos**: Reduce réplicas en horarios de bajo tráfico

**Nombre del recurso**: `{{ .Values.appName }}-hpa`
**Ejemplo**: `microservicio-app-hpa`

**Dependencia crítica**: Requiere **Metrics Server** instalado en el cluster.

#### Variables de Configuración

| Variable | Valores Posibles | Dependencias | Observaciones |
|----------|------------------|--------------|---------------|
| `HPA_ENABLED` | `true`, `false` | Requiere Metrics Server instalado | Dev: opcional, Staging/Prod: recomendado |
| `HPA_MIN_REPLICAS` | Entero >= 1 (ej: `1`, `3`) | Ninguna | Mínimo de pods (siempre activos) |
| `HPA_MAX_REPLICAS` | Entero > `HPA_MIN_REPLICAS` (ej: `10`) | Debe ser > `HPA_MIN_REPLICAS` | Máximo de pods (límite de escalado) |
| `HPA_TARGET_CPU` | Entero 1-100 (ej: `70`) | Ninguna | % de CPU objetivo (escala si supera este valor) |
| `HPA_TARGET_MEMORY` | Entero 1-100 (ej: `80`) | Ninguna | % de memoria objetivo (escala si supera este valor) |

#### Consideraciones y Dependencias

**Requisito: Metrics Server**:
- HPA necesita métricas de uso de pods (CPU/memoria)
- **Metrics Server** recolecta estas métricas desde kubelet
- Verificar instalación:
```bash
kubectl get deployment metrics-server -n kube-system
# Debe mostrar el deployment corriendo
```
- Instalar si no existe:
```bash
kubectl apply -f https://github.com/kubernetes-sigs/metrics-server/releases/latest/download/components.yaml
```

**Métricas disponibles**:
```bash
# Ver métricas de pods
kubectl top pods -n ns-app-dev

# Ver métricas de nodos
kubectl top nodes
```

**Comportamiento de escalado**:

```yaml
# Escenario ejemplo con HPA_TARGET_CPU=70
# Pod tiene resources.requests.cpu=100m

Current CPU usage: 50m (50% de 100m)  → No escala (debajo del 70%)
Current CPU usage: 80m (80% de 100m)  → ✅ Escala UP (supera 70%)
Current CPU usage: 20m (20% de 100m)  → ✅ Escala DOWN (muy bajo)
```

**Políticas de comportamiento** (definidas en values.yaml):

```yaml
behavior:
  scaleUp:
    stabilizationWindowSeconds: 0      # Sin espera para escalar UP
    policies:
    - type: Percent
      value: 100                        # Dobla pods cada vez (100% más)
      periodSeconds: 15                 # Cada 15 segundos

  scaleDown:
    stabilizationWindowSeconds: 300    # Espera 5 min antes de reducir (evita flapping)
    policies:
    - type: Pod
      value: 1                          # Reduce de 1 en 1 pod
      periodSeconds: 60                 # Cada minuto
```

**Ventajas de estas políticas**:
- **Escalado UP rápido**: Responde inmediatamente a picos de tráfico
- **Escalado DOWN lento**: Evita "flapping" (up-down-up constante)
- **Estabilidad**: 5 minutos de ventana asegura que la carga realmente bajó

**Interacción con Deployment**:
- HPA **sobrescribe** `spec.replicas` del Deployment dinámicamente
- **NO modificar manualmente** réplicas si HPA está habilitado:
```bash
# ❌ NO HACER (HPA lo sobrescribirá)
kubectl scale deployment microservicio-app-deployment --replicas=5

# ✅ Deshabilitar HPA primero si necesitas control manual
kubectl delete hpa microservicio-app-hpa
```

**Interacción con PDB**:
- PDB garantiza `minAvailable` pods durante mantenimientos
- HPA respeta PDB: No reduce pods si viola `minAvailable`
- **Recomendación**: `PDB.minAvailable` < `HPA.minReplicas`

**Interacción con Resource Requests**:
- HPA calcula % basándose en `resources.requests`, NO en `limits`
- Ejemplo:
```yaml
resources:
  requests:
    cpu: 100m      # HPA usa esto como referencia (100%)
  limits:
    cpu: 200m      # No afecta HPA
```

**Condiciones por ambiente**:
- **Dev**: `HPA_ENABLED=false` (1 réplica fija, ahorra recursos)
- **Staging**: `HPA_ENABLED=true`, 2-5 réplicas (testing de escalado)
- **Prod**: `HPA_ENABLED=true`, 3-10 réplicas (alta disponibilidad)

**Troubleshooting**:

```bash
# Ver estado del HPA
kubectl get hpa -n ns-app-dev
# Si muestra <unknown>: Metrics Server no instalado o pods sin resource requests

# Describir HPA (eventos)
kubectl describe hpa microservicio-app-hpa -n ns-app-dev
# Ver eventos de escalado (ScaleUp, ScaleDown)

# Ver logs de Metrics Server
kubectl logs -n kube-system -l k8s-app=metrics-server
```

**Limitaciones**:
- HPA solo escala réplicas, NO recursos por pod (eso requiere VPA - VerticalPodAutoscaler)
- No puede escalar a 0 (HPA v2 estándar; KEDA permite scale-to-zero)
- Latencia de métricas: ~30-60 segundos (no instantáneo)

---

### 5.6. ServiceAccount

#### Descripción

El **ServiceAccount** proporciona **identidad** a los pods, permitiéndoles autenticarse contra servicios externos sin credenciales hardcodeadas. Principales usos:

- **AWS IRSA** (IAM Roles for Service Accounts): Pods asumen roles de IAM automáticamente
- **Azure Workload Identity**: Pods acceden a Azure resources sin secrets
- **RBAC interno**: Permisos para acceder a la API de Kubernetes

**Nombre del recurso**: `{{ .Values.appName }}-sa`
**Ejemplo**: `microservicio-app-sa`

**Ventaja clave**: **Elimina credenciales hardcodeadas** en el código o variables de ambiente.

#### Variables de Configuración

| Variable | Valores Posibles | Dependencias | Observaciones |
|----------|------------------|--------------|---------------|
| `SERVICEACCOUNT_ENABLED` | `true`, `false` | Ninguna | Dev: opcional, Staging/Prod: recomendado si usa AWS/Azure |
| `SERVICEACCOUNT_IRSA_ROLE_ARN` | ARN de IAM Role (ej: `arn:aws:iam::123456789012:role/app-role`) | **AWS EKS** con OIDC configurado | Para acceso a S3, DynamoDB, Secrets Manager, etc |
| `SERVICEACCOUNT_AZURE_CLIENT_ID` | GUID (ej: `8e3928e1-03e5-4ba4-9e31-e1e2fe63f720`) | **Azure AKS** con Workload Identity | Para acceso a Key Vault, Storage, etc |

#### Funcionamiento: AWS IRSA

**Sin IRSA (método antiguo - inseguro)**:
```yaml
# ❌ Hardcoded credentials (MAL)
env:
- name: AWS_ACCESS_KEY_ID
  value: "AKIAIOSFODNN7EXAMPLE"
- name: AWS_SECRET_ACCESS_KEY
  value: "wJalrXUtnFEMI/K7MDENG/bPxRfiCYEXAMPLEKEY"
```

**Con IRSA (método moderno - seguro)**:
```yaml
# ✅ ServiceAccount con annotation
apiVersion: v1
kind: ServiceAccount
metadata:
  name: microservicio-app-sa
  annotations:
    eks.amazonaws.com/role-arn: arn:aws:iam::123456789012:role/microservicio-app-role

# Deployment usa el ServiceAccount
spec:
  serviceAccountName: microservicio-app-sa
```

**Resultado**:
1. EKS inyecta token OIDC en el pod (`/var/run/secrets/eks.amazonaws.com/serviceaccount/token`)
2. AWS SDK lee automáticamente el token
3. Asume el rol IAM especificado
4. Pod obtiene credenciales temporales (válidas 1-12 horas)

**Verificación dentro del pod**:
```bash
# Variables de ambiente automáticas
echo $AWS_ROLE_ARN
# arn:aws:iam::123456789012:role/microservicio-app-role

echo $AWS_WEB_IDENTITY_TOKEN_FILE
# /var/run/secrets/eks.amazonaws.com/serviceaccount/token

# Probar acceso a S3 (sin credenciales hardcodeadas)
aws s3 ls s3://my-bucket/
# Funciona automáticamente!
```

#### Funcionamiento: Azure Workload Identity

Similar a IRSA, pero para Azure:

```yaml
apiVersion: v1
kind: ServiceAccount
metadata:
  name: microservicio-app-sa
  annotations:
    azure.workload.identity/client-id: 8e3928e1-03e5-4ba4-9e31-e1e2fe63f720
```

**Resultado**: Pods pueden acceder a Azure Key Vault, Storage, etc sin secrets.

#### Consideraciones y Dependencias

**Requisitos para AWS IRSA**:
1. **Cluster EKS** con OIDC provider configurado:
```bash
# Verificar OIDC
aws eks describe-cluster --name my-cluster \
  --query "cluster.identity.oidc.issuer" --output text
# Debe retornar: https://oidc.eks.us-east-1.amazonaws.com/id/EXAMPLED539D4633E53DE1B71EXAMPLE
```

2. **IAM Role** con trust policy que permite el ServiceAccount:
```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Federated": "arn:aws:iam::123456789012:oidc-provider/oidc.eks.us-east-1.amazonaws.com/id/EXAMPLED539D4633E53DE1B71EXAMPLE"
      },
      "Action": "sts:AssumeRoleWithWebIdentity",
      "Condition": {
        "StringEquals": {
          "oidc.eks.us-east-1.amazonaws.com/id/EXAMPLED539D4633E53DE1B71EXAMPLE:sub": "system:serviceaccount:ns-app-prod:microservicio-app-sa"
        }
      }
    }
  ]
}
```

3. **IAM Policies** adjuntas al rol (permisos reales):
```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "s3:GetObject",
        "s3:PutObject",
        "s3:ListBucket"
      ],
      "Resource": [
        "arn:aws:s3:::my-bucket",
        "arn:aws:s3:::my-bucket/*"
      ]
    }
  ]
}
```

**Interacción con Deployment**:
```yaml
# Deployment debe especificar serviceAccountName
spec:
  template:
    spec:
      serviceAccountName: {{ .Values.appName }}-sa
```

**Permisos por ambiente**:
- **Dev**: Rol IAM con permisos amplios (facilitar desarrollo)
- **Staging**: Rol IAM con permisos similares a prod (testing)
- **Prod**: Rol IAM con **mínimos permisos** (least privilege)

**Troubleshooting AWS IRSA**:

```bash
# 1. Verificar ServiceAccount tiene la annotation
kubectl describe sa microservicio-app-sa -n ns-app-prod
# Debe mostrar: eks.amazonaws.com/role-arn: arn:aws:iam::...

# 2. Verificar variables de ambiente en pod
kubectl exec -it <pod-name> -n ns-app-prod -- env | grep AWS
# Debe mostrar:
#   AWS_ROLE_ARN=arn:aws:iam::123456789012:role/...
#   AWS_WEB_IDENTITY_TOKEN_FILE=/var/run/secrets/eks.amazonaws.com/serviceaccount/token

# 3. Verificar token existe
kubectl exec -it <pod-name> -n ns-app-prod -- ls -la /var/run/secrets/eks.amazonaws.com/serviceaccount/
# Debe mostrar: token (archivo)

# 4. Probar asunción de rol
kubectl exec -it <pod-name> -n ns-app-prod -- aws sts get-caller-identity
# Debe retornar el ARN del rol asumido
```

**Errores comunes**:
- `AccessDenied`: Trust policy del IAM Role no permite el ServiceAccount
- `InvalidIdentityToken`: OIDC provider no configurado o token expirado
- `No credentials found`: ServiceAccount no vinculado al Deployment

---

### 5.7. PDB (PodDisruptionBudget)

#### Descripción

El **PDB** garantiza **disponibilidad mínima** durante **interrupciones voluntarias** (mantenimientos programados del cluster, actualizaciones de nodos, etc). Define:
- **Mínimo de pods disponibles** (`minAvailable`) durante drain de nodos
- **Máximo de pods no disponibles** (`maxUnavailable`) simultáneamente

**Nombre del recurso**: `{{ .Values.appName }}-pdb`
**Ejemplo**: `microservicio-app-pdb`

**NO protege contra**:
- Fallos de hardware (nodos caídos)
- Pods eliminados manualmente (`kubectl delete pod`)
- OOMKilled, CrashLoopBackOff

**SÍ protege durante**:
- `kubectl drain` (sacar nodo de servicio)
- Actualizaciones de nodos del cluster
- Escalado down del cluster (reducción de nodos)

#### Variables de Configuración

| Variable | Valores Posibles | Dependencias | Observaciones |
|----------|------------------|--------------|---------------|
| `PDB_ENABLED` | `true`, `false` | **Solo útil con múltiples réplicas** (>= 2) | Dev (1 réplica): false, Staging/Prod: true |
| `PDB_MIN_AVAILABLE` | Entero o % (ej: `1`, `2`, `"50%"`) | **No usar junto con** `PDB_MAX_UNAVAILABLE` | Mínimo de pods que deben estar disponibles |
| `PDB_MAX_UNAVAILABLE` | Entero o % (ej: `1`, `"25%"`) | **No usar junto con** `PDB_MIN_AVAILABLE` | Máximo de pods que pueden estar no disponibles |

#### Consideraciones y Dependencias

**Regla de oro**: Solo usar **uno** de los dos parámetros:
- **Usar `minAvailable`** (recomendado): Define garantía de disponibilidad
- **O usar `maxUnavailable`**: Define límite de indisponibilidad
- **NO ambos simultáneamente** (error de validación)

**Ejemplos por ambiente**:

```bash
# Desarrollo (1 réplica - PDB no tiene sentido)
PDB_ENABLED=false
# Razón: Con 1 réplica, minAvailable=1 bloquearía CUALQUIER drain

# Staging (2 réplicas)
PDB_ENABLED=true
PDB_MIN_AVAILABLE=1        # Siempre 1 pod disponible
PDB_MAX_UNAVAILABLE=       # Vacío (no usar ambos)
# Permite: Drenar 1 nodo (deja 1 pod corriendo)
# Bloquea: Drenar ambos nodos simultáneamente

# Producción (3-10 réplicas HPA)
PDB_ENABLED=true
PDB_MIN_AVAILABLE=2        # Siempre mínimo 2 pods disponibles
PDB_MAX_UNAVAILABLE=       # Vacío
# Permite: Drenar nodos uno por uno (mínimo 2 pods siempre)
# Bloquea: Drenar múltiples nodos si quedan <2 pods
```

**Interacción con Deployment/HPA**:

```yaml
# PDB selector debe matchear labels del Deployment
selector:
  matchLabels:
    app: {{ .Values.appName }}  # Mismo label que Deployment
```

**Escenarios de bloqueo**:

```bash
# Escenario: Staging con 2 réplicas, minAvailable=1
kubectl get pods -n ns-app-staging
# pod/microservicio-app-deployment-abc (node-1)
# pod/microservicio-app-deployment-def (node-2)

# Drenar node-1 (OK)
kubectl drain node-1 --ignore-daemonsets
# ✅ Permitido: Queda 1 pod en node-2 (cumple minAvailable=1)

# Drenar node-2 simultáneamente (BLOQUEADO)
kubectl drain node-2 --ignore-daemonsets
# ❌ Cannot evict pod as it would violate the pod's disruption budget
# Razón: Quedarían 0 pods (viola minAvailable=1)

# Solución: Esperar a que pod de node-1 se reprograme en otro nodo, luego drenar node-2
```

**PDB con porcentajes**:

```yaml
# Opción 1: Valor absoluto
minAvailable: 2              # Siempre 2 pods

# Opción 2: Porcentaje
minAvailable: "50%"          # Siempre 50% de los pods
# Ventaja: Escala automáticamente con HPA
# Ejemplo: 4 réplicas → minAvailable=2, 10 réplicas → minAvailable=5
```

**Interacción con Rolling Updates**:
- PDB **NO afecta** rolling updates del Deployment
- Rolling updates son controlados por `maxUnavailable` y `maxSurge` del Deployment
- PDB solo afecta evictions (drain, pod disruptions)

**Recomendaciones**:

| Réplicas | PDB Config | Razón |
|----------|------------|-------|
| 1 | `enabled: false` | PDB bloquearía drain (no tiene sentido) |
| 2 | `minAvailable: 1` | Garantiza al menos 1 pod siempre |
| 3-5 | `minAvailable: 2` | Alta disponibilidad (mínimo 2 pods) |
| 5+ | `minAvailable: 50%` | Escala con réplicas (flexible) |

**Troubleshooting**:

```bash
# Ver PDB
kubectl get pdb -n ns-app-prod
# NAME                    MIN AVAILABLE   MAX UNAVAILABLE   ALLOWED DISRUPTIONS   AGE
# microservicio-app-pdb   2               N/A               1                     5d

# Describir PDB (ver eventos)
kubectl describe pdb microservicio-app-pdb -n ns-app-prod

# Ver disruptions permitidas
kubectl get pdb microservicio-app-pdb -n ns-app-prod -o jsonpath='{.status.disruptionsAllowed}'
# 1 = Puede drenar 1 pod más
# 0 = NO puede drenar ningún pod (bloqueado)

# Forzar drain (PELIGROSO - solo en emergencias)
kubectl drain node-1 --ignore-daemonsets --disable-eviction
# Omite PDB (puede causar downtime)
```

**Errores comunes**:
- `Cannot evict pod`: PDB bloquea drain (normal, funcionando correctamente)
- `PDB.minAvailable > replicas`: Configuración imposible (ej: minAvailable=3 con 2 réplicas)
- `minAvailable y maxUnavailable ambos definidos`: Error de validación (usar solo uno)

---

## 6. Guía Educativa de Helm y Kubernetes

Para aprender en profundidad cómo funciona Helm, la sintaxis de templating, y conceptos detallados de Kubernetes, consulta:

- **`k8s/README.md`**: Guía educativa completa de Helm y Kubernetes
  - ¿Qué es Helm y por qué usarlo?
  - Sintaxis de templating (Go templates)
  - Conceptos de Kubernetes explicados (Pods, Deployments, Resources, Probes)
  - Comandos útiles de kubectl y helm
  - Troubleshooting detallado
  - Ejemplos prácticos paso a paso
  - Mejores prácticas

Esta guía es ideal para desarrolladores que están aprendiendo Helm/Kubernetes o necesitan entender los conceptos detrás de este artefacto.

---

## 7. Flujo Completo de Despliegue

### Workflow Local (Desarrollo)

```bash
# 1. Editar configuración de la aplicación
vi app/application.yaml

# 2. Validar templates (sin desplegar)
./render-template.sh --env dev

# 3. Revisar manifiestos generados
cat rendered-manifests/deployment.yaml

# 4. Desplegar al cluster de desarrollo
./deployment.sh --env dev

# 5. Verificar despliegue
kubectl get all -n ns-app-dev
kubectl logs -f deployment/microservicio-app-deployment -n ns-app-dev
```

### Workflow Azure DevOps (Staging/Producción)

```yaml
# azure-pipelines.yml (ejemplo conceptual)
trigger:
  - main

stages:
- stage: Build
  jobs:
  - job: BuildDocker
    steps:
    - task: Docker@2
      inputs:
        command: build
        dockerfile: Dockerfile
        tags: $(Build.BuildId)

- stage: DeployStaging
  dependsOn: Build
  variables:
  - group: microservicio-staging  # Library Group con variables
  jobs:
  - job: HelmDeploy
    steps:
    - task: HelmDeploy@0
      inputs:
        command: upgrade
        chartPath: k8s/
        releaseName: microservicio-app
        namespace: $(NAMESPACE)
        overrideValues: |
          replicaCount=$(REPLICA_COUNT)
          image.tag=$(Build.BuildId)
          hpa.enabled=$(HPA_ENABLED)
          # ... todas las variables del Library Group

- stage: DeployProd
  dependsOn: DeployStaging
  condition: and(succeeded(), eq(variables['Build.SourceBranch'], 'refs/heads/main'))
  variables:
  - group: microservicio-prod
  jobs:
  - job: HelmDeploy
    steps:
    # Similar a staging, pero con variables de prod
```

---

## 8. Seguridad y Mejores Prácticas

### Secretos y Credenciales

❌ **NO hacer**:
```yaml
# NO hardcodear secretos en values.yaml
database:
  password: "myPassword123"  # ❌ MAL

# NO usar ConfigMaps para secretos
configMap:
  data:
    DB_PASSWORD: "myPassword123"  # ❌ MAL (ConfigMap es texto plano)
```

✅ **SÍ hacer**:
```bash
# Usar Kubernetes Secrets
kubectl create secret generic db-credentials \
  --from-literal=password='mySecretPassword' \
  -n ns-app-prod

# O mejor: AWS Secrets Manager / Azure Key Vault con CSI Driver
# O mejor aún: External Secrets Operator
```

### Imágenes Docker

❌ **NO usar**:
```yaml
image:
  tag: latest  # ❌ No reproducible, inseguro
```

✅ **SÍ usar**:
```yaml
image:
  tag: v1.2.3           # ✅ Versionado semántico
  # O
  tag: sha256:abc123... # ✅ Digest (inmutable)
```

### Resource Limits

✅ **Siempre definir**:
```yaml
resources:
  requests:   # Lo que K8s garantiza
    memory: 256Mi
    cpu: 200m
  limits:     # Máximo permitido (evita noisy neighbors)
    memory: 512Mi
    cpu: 400m
```

### Health Checks

✅ **Siempre configurar**:
```yaml
livenessProbe:   # Reinicia pods colgados
  httpGet:
    path: /health
    port: 8080
  initialDelaySeconds: 30

readinessProbe:  # Controla tráfico del Service
  httpGet:
    path: /ready
    port: 8080
  initialDelaySeconds: 10
```

---

## 9. Troubleshooting

### Pods no arrancan

```bash
# Ver estado de pods
kubectl get pods -n ns-app-dev

# Describir pod (eventos)
kubectl describe pod <pod-name> -n ns-app-dev

# Ver logs
kubectl logs <pod-name> -n ns-app-dev

# Ver logs previos (si crasheó)
kubectl logs <pod-name> -n ns-app-dev --previous
```

### Ingress no funciona

```bash
# Verificar Ingress
kubectl describe ingress microservicio-app-ingress -n ns-app-dev

# Ver logs del Ingress Controller
kubectl logs -n ingress-nginx -l app.kubernetes.io/name=ingress-nginx

# Probar Service directamente (port-forward)
kubectl port-forward -n ns-app-dev svc/microservicio-app-service 8080:80
curl http://localhost:8080
```

### HPA muestra <unknown>

```bash
# Verificar Metrics Server
kubectl get deployment metrics-server -n kube-system

# Ver métricas de pods
kubectl top pods -n ns-app-dev

# Si no hay métricas: instalar Metrics Server
kubectl apply -f https://github.com/kubernetes-sigs/metrics-server/releases/latest/download/components.yaml
```

### ServiceAccount IRSA no funciona

```bash
# Verificar annotation del ServiceAccount
kubectl describe sa microservicio-app-sa -n ns-app-prod

# Verificar variables en pod
kubectl exec -it <pod-name> -n ns-app-prod -- env | grep AWS

# Probar asunción de rol
kubectl exec -it <pod-name> -n ns-app-prod -- aws sts get-caller-identity
```

---

## 10. Mantenimiento y Actualizaciones

### Actualizar imagen de la aplicación

```bash
# 1. Editar .env.{ambiente}
vi .env.prod
# Cambiar: IMAGE_TAG=v1.2.3

# 2. Redesplegar
./deployment.sh --env prod

# 3. Monitorear rollout
kubectl rollout status deployment/microservicio-app-deployment -n ns-app-prod
```

### Rollback a versión anterior

```bash
# Ver historial de releases
helm history microservicio-app -n ns-app-prod

# Rollback a revisión anterior
helm rollback microservicio-app -n ns-app-prod

# O a revisión específica
helm rollback microservicio-app 5 -n ns-app-prod
```

### Actualizar configuración (application.yaml)

```bash
# 1. Editar configuración
vi app/application.yaml

# 2. Redesplegar (actualiza ConfigMap)
./deployment.sh --env dev

# 3. Recrear pods (forzar lectura de nuevo ConfigMap)
kubectl rollout restart deployment/microservicio-app-deployment -n ns-app-dev
```

