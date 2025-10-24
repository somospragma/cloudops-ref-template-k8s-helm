# ANÁLISIS DE VARIABILIZACIÓN - HELM CHART

## Objetivo

Clasificar todas las variables del Helm Chart en:
- **Library Groups (Azure DevOps)**: Variables que disparan pipeline completo con BUILD
- **values.yaml (Git)**: Variables que solo disparan re-deployment de Kubernetes (sin build)

## Criterios de Clasificación

```
┌─────────────────────────────────────────────────────────────────┐
│  LIBRARY GROUPS                                                 │
│  - Variables operacionales (recursos, scaling, networking)     │
│  - Variables de infraestructura (namespace, image tag)         │
│  - Variables de configuración externa (dominios, secrets)      │
│  - Todo lo que NO afecta funcionamiento interno de la app      │
└─────────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────────┐
│  values.yaml (GIT)                                              │
│  - Variables estructurales de la aplicación                    │
│  - Configuración que la app ESPERA en runtime                  │
│  - Puertos, paths internos, health checks                      │
│  - Todo lo que SI afecta funcionamiento interno de la app      │
└─────────────────────────────────────────────────────────────────┘
```

---

## INVENTARIO COMPLETO DE VARIABLES POR OBJETO

### 1. DEPLOYMENT (`k8s/templates/deployment.yaml`)

#### Variables encontradas:
```yaml
# Metadata
.Values.appName                                    # Nombre de la aplicación
.Values.namespace                                  # Namespace de despliegue
.Values.image.tag                                  # Tag para labels (versión)

# Spec - Replicas
.Values.replicaCount                               # Número de réplicas

# Spec - Image
.Values.image.registry                             # Registry del contenedor (docker.io, ECR)
.Values.image.repository                           # Repositorio de la imagen
.Values.image.tag                                  # Tag de la imagen
.Values.image.pullPolicy                           # Política de pull (Always, IfNotPresent, Never)

# Spec - ServiceAccount
.Values.serviceAccount.enabled                     # Habilitar service account

# Spec - Container
.Values.container.port                             # Puerto del contenedor

# Spec - VolumeMounts
.Values.configMap.enabled                          # Habilitar montaje de ConfigMap

# Spec - Resources
.Values.resources.requests.memory                  # Memoria solicitada
.Values.resources.requests.cpu                     # CPU solicitada
.Values.resources.limits.memory                    # Límite de memoria
.Values.resources.limits.cpu                       # Límite de CPU

# Spec - Liveness Probe
.Values.container.livenessProbe.path               # Path del endpoint de liveness
.Values.container.livenessProbe.port               # Puerto del liveness probe
.Values.container.livenessProbe.initialDelaySeconds  # Delay inicial
.Values.container.livenessProbe.periodSeconds      # Período de verificación
.Values.container.livenessProbe.timeoutSeconds     # Timeout de la petición
.Values.container.livenessProbe.failureThreshold   # Intentos antes de reiniciar

# Spec - Readiness Probe
.Values.container.readinessProbe.path              # Path del endpoint de readiness
.Values.container.readinessProbe.port              # Puerto del readiness probe
.Values.container.readinessProbe.initialDelaySeconds  # Delay inicial
.Values.container.readinessProbe.periodSeconds     # Período de verificación
.Values.container.readinessProbe.timeoutSeconds    # Timeout de la petición
.Values.container.readinessProbe.failureThreshold  # Intentos antes de marcar not ready
```

**Total variables Deployment: 25**

---

### 2. SERVICE (`k8s/templates/service.yaml`)

#### Variables encontradas:
```yaml
# Metadata
.Values.appName                                    # Nombre de la aplicación
.Values.namespace                                  # Namespace

# Spec
.Values.service.type                               # Tipo de service (ClusterIP, LoadBalancer, NodePort)
.Values.service.port                               # Puerto expuesto por el service
.Values.service.targetPort                         # Puerto del contenedor (target)
```

**Total variables Service: 5**

---

### 3. INGRESS (`k8s/templates/ingress.yaml`)

#### Variables encontradas:
```yaml
# Condicional
.Values.ingress.enabled                            # Habilitar/deshabilitar ingress

# Metadata
.Values.appName                                    # Nombre de la aplicación
.Values.namespace                                  # Namespace
.Values.environment                                # Ambiente (dev, staging, prod)

# Annotations - Nginx
.Values.ingress.annotations.sslRedirect            # Redirigir HTTP a HTTPS
.Values.ingress.annotations.forceSSLRedirect       # Forzar redirección SSL
.Values.ingress.annotations.rewriteTarget          # Reescribir path antes de enviar al backend

# Annotations - AWS ALB
.Values.ingress.className                          # Clase del ingress (nginx, alb)
.Values.ingress.annotations.awsScheme              # Esquema del ALB (internet-facing, internal)
.Values.ingress.annotations.awsTargetType          # Tipo de target (ip, instance)
.Values.ingress.annotations.awsCertificateArn      # ARN del certificado ACM

# Annotations - mTLS
.Values.ingress.mtls.enabled                       # Habilitar mTLS
.Values.ingress.mtls.secretName                    # Nombre del secret con certificados cliente
.Values.ingress.mtls.verifyClient                  # Modo de verificación (on, optional, off)
.Values.ingress.mtls.passCertToUpstream            # Pasar certificado al backend

# Annotations - Custom
.Values.ingress.annotations.custom                 # Annotations personalizadas adicionales

# Spec - IngressClassName
.Values.ingress.className                          # Clase del ingress controller

# Spec - TLS
.Values.ingress.tls.enabled                        # Habilitar TLS
.Values.ingress.tls.hosts                          # Hosts para TLS (array)
.Values.ingress.tls.secretName                     # Nombre del secret TLS

# Spec - Rules
.Values.ingress.rules[].host                       # Host del ingress (opcional)
.Values.ingress.rules[].paths[].path               # Path de la ruta
.Values.ingress.rules[].paths[].pathType           # Tipo de path (Prefix, Exact)
.Values.ingress.rules[].paths[].servicePort        # Puerto del service
```

**Total variables Ingress: 24**

---

### 4. HPA - HorizontalPodAutoscaler (`k8s/templates/hpa.yaml`)

#### Variables encontradas:
```yaml
# Condicional
.Values.hpa.enabled                                # Habilitar/deshabilitar HPA

# Metadata
.Values.appName                                    # Nombre de la aplicación
.Values.namespace                                  # Namespace
.Values.environment                                # Ambiente

# Spec
.Values.hpa.minReplicas                            # Mínimo de réplicas
.Values.hpa.maxReplicas                            # Máximo de réplicas
.Values.hpa.targetCPUUtilizationPercentage         # Target de CPU (%)
.Values.hpa.targetMemoryUtilizationPercentage      # Target de memoria (%)
.Values.hpa.behavior                               # Comportamiento de scaling (opcional)
```

**Total variables HPA: 9**

---

### 5. SERVICEACCOUNT (`k8s/templates/serviceaccount.yaml`)

#### Variables encontradas:
```yaml
# Condicional
.Values.serviceAccount.enabled                     # Habilitar/deshabilitar ServiceAccount

# Metadata
.Values.appName                                    # Nombre de la aplicación
.Values.namespace                                  # Namespace
.Values.environment                                # Ambiente

# Annotations - AWS IRSA
.Values.serviceAccount.annotations                 # Objeto de annotations
.Values.serviceAccount.annotations.irsaRoleArn     # ARN del IAM role para IRSA

# Annotations - Azure Workload Identity
.Values.serviceAccount.annotations.azureClientId   # Client ID para Azure

# Annotations - Custom
.Values.serviceAccount.annotations.custom          # Annotations personalizadas
```

**Total variables ServiceAccount: 8**

---

### 6. PDB - PodDisruptionBudget (`k8s/templates/pdb.yaml`)

#### Variables encontradas:
```yaml
# Condicional
.Values.pdb.enabled                                # Habilitar/deshabilitar PDB

# Metadata
.Values.appName                                    # Nombre de la aplicación
.Values.namespace                                  # Namespace
.Values.environment                                # Ambiente

# Spec
.Values.pdb.minAvailable                           # Mínimo de pods disponibles (número o %)
.Values.pdb.maxUnavailable                         # Máximo de pods no disponibles (número o %)
```

**Total variables PDB: 6**

---

### 7. CONFIGMAP (`k8s/templates/configmap.yaml`)

#### Variables encontradas:
```yaml
# Condicional
.Values.configMap.enabled                          # Habilitar/deshabilitar ConfigMap

# Metadata
.Values.appName                                    # Nombre de la aplicación
.Values.namespace                                  # Namespace

# Data
.Values.application                                # Objeto completo de app/application.yaml
```

**Total variables ConfigMap: 4**

---

## RESUMEN DE VARIABLES POR OBJETO

| Objeto Kubernetes | Cantidad de Variables | Complejidad |
|-------------------|----------------------|-------------|
| **Deployment** | 25 | Alta |
| **Ingress** | 24 | Alta |
| **HPA** | 9 | Media |
| **ServiceAccount** | 8 | Media |
| **PDB** | 6 | Baja |
| **Service** | 5 | Baja |
| **ConfigMap** | 4 | Baja |
| **TOTAL** | **81** | - |

---

## TABLA DE CLASIFICACIÓN PROPUESTA

### Leyenda:
- **LIBRARY**: Variable en Library Groups (Azure DevOps)
- **GIT**: Variable en values.yaml (Git)
- **CRÍTICO**: Cambio incorrecto puede romper la aplicación
- **SEGURO**: Cambio no afecta funcionalidad de la app

---

### TABLA COMPLETA DE VARIABLES

| # | Variable | Objeto | Ubicación | Riesgo | Justificación |
|---|----------|--------|-----------|--------|---------------|
| 1 | `appName` | Todos | LIBRARY | SEGURO | Identificador de recursos K8s, no afecta código de la app |
| 2 | `namespace` | Todos | LIBRARY | SEGURO | Infraestructura, define dónde se despliega |
| 3 | `environment` | Varios | LIBRARY | SEGURO | Label para identificar ambiente (dev/staging/prod) |
| 4 | `replicaCount` | Deployment | LIBRARY | SEGURO | Operacional, no afecta funcionalidad |
| 5 | `image.registry` | Deployment | LIBRARY | SEGURO | Infraestructura (docker.io, ECR, etc.) |
| 6 | `image.repository` | Deployment | LIBRARY | SEGURO | Nombre de la imagen en el registry |
| 7 | `image.tag` | Deployment | LIBRARY | SEGURO | Versión de la imagen a desplegar |
| 8 | `image.pullPolicy` | Deployment | LIBRARY | SEGURO | Política de descarga de imágenes |
| 9 | `resources.requests.memory` | Deployment | LIBRARY | SEGURO | Recursos, ajustable sin afectar app |
| 10 | `resources.requests.cpu` | Deployment | LIBRARY | SEGURO | Recursos, ajustable sin afectar app |
| 11 | `resources.limits.memory` | Deployment | LIBRARY | SEGURO | Recursos, ajustable sin afectar app |
| 12 | `resources.limits.cpu` | Deployment | LIBRARY | SEGURO | Recursos, ajustable sin afectar app |
| 13 | `container.port` | Deployment | GIT | CRÍTICO | **Puerto donde la app escucha, debe coincidir con código** |
| 14 | `container.livenessProbe.path` | Deployment | GIT | CRÍTICO | **Endpoint que la app expone, debe existir en código** |
| 15 | `container.livenessProbe.port` | Deployment | GIT | CRÍTICO | **Debe coincidir con container.port** |
| 16 | `container.livenessProbe.initialDelaySeconds` | Deployment | GIT | SEGURO | Timing de health check, ajustable según app |
| 17 | `container.livenessProbe.periodSeconds` | Deployment | GIT | SEGURO | Timing de health check |
| 18 | `container.livenessProbe.timeoutSeconds` | Deployment | GIT | SEGURO | Timing de health check |
| 19 | `container.livenessProbe.failureThreshold` | Deployment | GIT | SEGURO | Configuración de tolerancia a fallos |
| 20 | `container.readinessProbe.path` | Deployment | GIT | CRÍTICO | **Endpoint que la app expone, debe existir en código** |
| 21 | `container.readinessProbe.port` | Deployment | GIT | CRÍTICO | **Debe coincidir con container.port** |
| 22 | `container.readinessProbe.initialDelaySeconds` | Deployment | GIT | SEGURO | Timing de health check |
| 23 | `container.readinessProbe.periodSeconds` | Deployment | GIT | SEGURO | Timing de health check |
| 24 | `container.readinessProbe.timeoutSeconds` | Deployment | GIT | SEGURO | Timing de health check |
| 25 | `container.readinessProbe.failureThreshold` | Deployment | GIT | SEGURO | Configuración de tolerancia a fallos |
| 26 | `service.type` | Service | GIT | SEGURO | Arquitectura del service (rara vez cambia) |
| 27 | `service.port` | Service | LIBRARY | SEGURO | Puerto externo del service, ajustable |
| 28 | `service.targetPort` | Service | GIT | CRÍTICO | **Debe coincidir con container.port** |
| 29 | `ingress.enabled` | Ingress | LIBRARY | SEGURO | Activar/desactivar ingress |
| 30 | `ingress.className` | Ingress | LIBRARY | SEGURO | Clase del ingress controller (nginx, alb) |
| 31 | `ingress.annotations.sslRedirect` | Ingress | LIBRARY | SEGURO | Configuración de SSL |
| 32 | `ingress.annotations.forceSSLRedirect` | Ingress | LIBRARY | SEGURO | Configuración de SSL |
| 33 | `ingress.annotations.rewriteTarget` | Ingress | LIBRARY | CRÍTICO | **Puede romper ruteo si no coincide con lo que la app espera** |
| 34 | `ingress.annotations.awsScheme` | Ingress | LIBRARY | SEGURO | Configuración de AWS ALB |
| 35 | `ingress.annotations.awsTargetType` | Ingress | LIBRARY | SEGURO | Configuración de AWS ALB |
| 36 | `ingress.annotations.awsCertificateArn` | Ingress | LIBRARY | SEGURO | Certificado SSL en AWS |
| 37 | `ingress.annotations.custom` | Ingress | LIBRARY | SEGURO | Annotations adicionales personalizadas |
| 38 | `ingress.tls.enabled` | Ingress | LIBRARY | SEGURO | Activar/desactivar TLS |
| 39 | `ingress.tls.hosts` | Ingress | LIBRARY | SEGURO | Hosts para TLS |
| 40 | `ingress.tls.secretName` | Ingress | LIBRARY | SEGURO | Nombre del secret TLS |
| 41 | `ingress.mtls.enabled` | Ingress | LIBRARY | SEGURO | Activar/desactivar mTLS |
| 42 | `ingress.mtls.secretName` | Ingress | LIBRARY | SEGURO | Secret con certificados cliente |
| 43 | `ingress.mtls.verifyClient` | Ingress | LIBRARY | SEGURO | Modo de verificación mTLS |
| 44 | `ingress.mtls.passCertToUpstream` | Ingress | LIBRARY | SEGURO | Pasar cert al backend |
| 45 | `ingress.rules[].host` | Ingress | LIBRARY | SEGURO | Dominio del ingress |
| 46 | `ingress.rules[].paths[].path` | Ingress | LIBRARY | CRÍTICO | **Path de ruteo - debe coincidir con lo que la app espera** |
| 47 | `ingress.rules[].paths[].pathType` | Ingress | GIT | SEGURO | Tipo de matching (Prefix, Exact) - arquitectura |
| 48 | `ingress.rules[].paths[].servicePort` | Ingress | LIBRARY | SEGURO | Puerto del service al que rutear |
| 49 | `hpa.enabled` | HPA | LIBRARY | SEGURO | Activar/desactivar autoscaling |
| 50 | `hpa.minReplicas` | HPA | LIBRARY | SEGURO | Mínimo de réplicas |
| 51 | `hpa.maxReplicas` | HPA | LIBRARY | SEGURO | Máximo de réplicas |
| 52 | `hpa.targetCPUUtilizationPercentage` | HPA | LIBRARY | SEGURO | Target de CPU para scaling |
| 53 | `hpa.targetMemoryUtilizationPercentage` | HPA | LIBRARY | SEGURO | Target de memoria para scaling |
| 54 | `hpa.behavior` | HPA | LIBRARY | SEGURO | Comportamiento de scaling |
| 55 | `serviceAccount.enabled` | ServiceAccount | LIBRARY | SEGURO | Activar/desactivar SA |
| 56 | `serviceAccount.annotations.irsaRoleArn` | ServiceAccount | LIBRARY | SEGURO | ARN del IAM role (AWS) |
| 57 | `serviceAccount.annotations.azureClientId` | ServiceAccount | LIBRARY | SEGURO | Client ID (Azure) |
| 58 | `serviceAccount.annotations.custom` | ServiceAccount | LIBRARY | SEGURO | Annotations personalizadas |
| 59 | `pdb.enabled` | PDB | LIBRARY | SEGURO | Activar/desactivar PDB |
| 60 | `pdb.minAvailable` | PDB | LIBRARY | SEGURO | Pods mínimos disponibles |
| 61 | `pdb.maxUnavailable` | PDB | LIBRARY | SEGURO | Pods máximos no disponibles |
| 62 | `configMap.enabled` | ConfigMap | LIBRARY | SEGURO | Activar/desactivar ConfigMap |
| 63 | `application` (completo) | ConfigMap | GIT | CRÍTICO | **Configuración completa de la aplicación (Spring Boot)** |

---

## RESUMEN EJECUTIVO

### Distribución:
- **LIBRARY GROUPS**: 54 variables (86%)
- **GIT (values.yaml)**: 9 variables (14%)

### Variables Críticas en GIT:
1. `container.port` - Puerto donde la app escucha
2. `container.livenessProbe.path` - Endpoint de health check
3. `container.livenessProbe.port` - Puerto del health check
4. `container.readinessProbe.path` - Endpoint de readiness
5. `container.readinessProbe.port` - Puerto del readiness
6. `service.targetPort` - Debe = container.port
7. `application` (app/application.yaml) - Config de Spring Boot

### Variables de Riesgo en LIBRARY:
1. `ingress.annotations.rewriteTarget` - Puede romper ruteo
2. `ingress.rules[].paths[].path` - Debe coincidir con app

---

## RECOMENDACIONES IMPORTANTES

### 1. Variables Críticas de Ingress
```yaml
# ESTAS DOS deben estar coordinadas:
ingress.rules[].paths[].path: /ficohsa        # En LIBRARY
ingress.annotations.rewriteTarget: /           # En LIBRARY

# Si la app espera requests en "/" (raíz)
# Entonces: path=/ficohsa + rewriteTarget=/

# Si cambias path a /api y NO actualizas rewriteTarget
# La app recibirá /api y puede no funcionar
```

**Solución**: Documentación clara + validación en pipeline

### 2. Dependencia container.port
```yaml
# ESTAS TRES deben coincidir:
container.port: 80                    # En GIT
service.targetPort: 80                # En GIT
container.livenessProbe.port: 80      # En GIT
container.readinessProbe.port: 80     # En GIT

# Si cambias container.port, DEBES cambiar las otras
```

**Solución**: En values.yaml usar references:
```yaml
container:
  port: 80

service:
  targetPort: 80  # Debe = container.port

container:
  livenessProbe:
    port: 80  # Debe = container.port
```

### 3. Health Check Paths
```yaml
# Los paths deben existir en el código de la app:
container.livenessProbe.path: /health   # La app DEBE exponer este endpoint
container.readinessProbe.path: /ready   # La app DEBE exponer este endpoint
```

**Solución**: El desarrollador define estos valores en values.yaml cuando desarrolla la app

### 4. application.yaml (ConfigMap)
Este archivo contiene TODA la configuración de Spring Boot:
- URLs de base de datos
- Endpoints de APIs externas
- Feature flags
- Logging levels

**Debe vivir en GIT** porque es parte integral de la configuración de la aplicación.

---

## PLAN DE IMPLEMENTACIÓN SUGERIDO

### Fase 1: Preparación
1. Crear `values.yaml` minimalista en Git con solo las 9 variables críticas
2. Documentar claramente qué NO se debe cambiar sin rebuild
3. Crear plantilla de Library Groups con las 54 variables

### Fase 2: Validación
1. Implementar smoke tests después de cambios en values.yaml
2. Validar que health check endpoints responden
3. Validar que ingress rutea correctamente

### Fase 3: Documentación
1. Guía para desarrolladores: "Qué va en values.yaml"
2. Guía para CloudOps: "Qué va en Library Groups"
3. Matriz de compatibilidad imagen ↔ configuración

### Fase 4: Pipeline
1. Pipeline con dos paths:
   - Cambio en Git → Solo K8s deployment
   - Cambio en Library → Build completo
2. Notificaciones claras de qué se está cambiando
3. Rollback automático si fallan health checks

---

## CONCLUSIÓN

Tu approach de separar variables entre Library Groups y Git es **correcto y sigue best practices**.

**Ventajas**:
- Optimiza tiempos (1-2 min vs 5-10 min)
- Reduce riesgo de rebuilds innecesarios
- Separa concerns (infra vs código)
- Da autonomía a CloudOps para ajustes operacionales

**Riesgos mitigables**:
- Drift entre imagen y config (solución: documentación + validación)
- Cambios en ingress path sin rewriteTarget (solución: smoke tests)
- Falta de claridad en qué cambiar dónde (solución: esta documentación)

**Recomendación final**: 
**PROCEDER** con este modelo, implementando las validaciones y documentación sugeridas.

---

## Referencias
- [Helm Best Practices - Values Files](https://helm.sh/docs/chart_best_practices/values/)
- [GitOps Principles](https://www.gitops.tech/)
- [Kubernetes Health Checks Best Practices](https://kubernetes.io/docs/tasks/configure-pod-container/configure-liveness-readiness-startup-probes/)
- [CNCF - Application Definition & Image Build](https://landscape.cncf.io/guide#app-definition-and-development--application-definition-image-build)
