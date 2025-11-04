# Manual de Instalación Automatizado
## AWS Load Balancer Controller, NGINX Ingress Controller y EKS Auto Mode

### Tabla de Contenidos
1. [Prerrequisitos](#prerrequisitos)
2. [Estructura del Proyecto](#estructura-del-proyecto)
3. [Configuración](#configuración)
4. [Scripts Disponibles](#scripts-disponibles)
5. [Instalación](#instalación)
6. [EKS Auto Mode](#eks-auto-mode)
7. [Verificación](#verificación)
8. [Troubleshooting](#troubleshooting)
9. [Seguridad](#seguridad)

---

## Prerrequisitos

### Herramientas Requeridas

| Herramienta | Versión Mínima | Propósito |
|-------------|----------------|-----------|
| `kubectl` | 1.24+ | Interacción con cluster Kubernetes |
| `helm` | 3.8+ | Gestión de paquetes Kubernetes |
| `eksctl` | 0.147+ | Gestión de clusters EKS |
| `aws cli` | 2.13+ | Interacción con servicios AWS |
| `curl` | 7.68+ | Descarga de archivos |

### Verificación de Prerrequisitos
```bash
# Verificar herramientas instaladas
kubectl version --client
helm version
eksctl version
aws --version
curl --version

# Verificar conexión al cluster
kubectl get nodes
```

### Permisos AWS Requeridos
- `eks:DescribeCluster`
- `iam:CreateRole`, `iam:AttachRolePolicy`, `iam:CreatePolicy`
- `ec2:DescribeSecurityGroups`, `ec2:DescribeSubnets`
- `sts:GetCallerIdentity`

---

## Estructura del Proyecto

```
prueba_controladores/
├── config.env                     # Configuración principal
├── install-all-controllers.sh     # Script maestro de instalación
├── install-aws-lb-controller.sh   # Instalador AWS Load Balancer Controller
├── install-nginx-ingress.sh       # Instalador NGINX Ingress Controller
├── install-cluster-autoscaler.sh  # Instalador Cluster Autoscaler
├── deploy-nodeclass-nodepool.sh   # Despliegue EKS Auto Mode
├── uninstall-controllers.sh       # Desinstalador
├── verify-installation.sh         # Verificador de instalación
├── monitor-app.sh                 # Monitor de aplicaciones
├── auto-mode/                     # Configuraciones EKS Auto Mode
│   ├── nodeclass.yaml
│   ├── nodepool.yaml
│   └── test-pod.yaml
├── *.yaml                         # Manifiestos de ejemplo
└── README.md                      # Esta documentación
```

---

## Configuración

### Archivo config.env

El archivo `config.env` contiene todas las variables de configuración necesarias:

```bash
# =============================================================================
# CONFIGURACIÓN PRINCIPAL
# =============================================================================

# 🎯 SWITCHES DE INSTALACIÓN
export INSTALL_AWS_LB_CONTROLLER="true"
export INSTALL_NGINX_CONTROLLER="true"
export INSTALL_CLUSTER_AUTOSCALER="false"
export INSTALL_NODECLASS_NODEPOOL="true"

# 🏗️ CONFIGURACIÓN DEL CLUSTER
export CLUSTER_NAME="mi-cluster-eks"
export AWS_REGION="us-east-1"
export AWS_ACCOUNT_ID="123456789012"
export VPC_ID="vpc-xxxxxxxxx"
export AWS_PROFILE="default"

# 🌐 CONFIGURACIÓN DE RED
export PUBLIC_SUBNETS="subnet-abc123,subnet-def456"
export PRIVATE_SUBNETS="subnet-ghi789,subnet-jkl012"
export SUBNET_TYPE="public"
export INGRESS_SECURITY_GROUP="sg-xxxxxxxxx"

# 🔐 CERTIFICADOS SSL
export ACM_CERTIFICATE_ARN="arn:aws:acm:region:account:certificate/cert-id"

# 🚀 CONFIGURACIÓN NGINX
export NGINX_NAMESPACE="ingress-nginx-ns"
export NLB_NAME="mi-nlb-ingress"
export TARGET_TYPE="ip"
export NGINX_CONTROLLER_VERSION="4.12.7"

# ⚙️ CONFIGURACIÓN AWS LB CONTROLLER
export AWS_LB_CONTROLLER_VERSION="1.13.2"
export CREATE_IAM_ROLE="true"
export CREATE_IAM_POLICY="true"
export CREATE_SERVICE_ACCOUNT="true"

# 🏗️ EKS AUTO MODE
export NODECLASS_NAME="test-customize"
export NODEPOOL_NAME="my-node-pool"
export NODE_ROLE_NAME="AUTO-MODE"
export INSTANCE_NAME="mi-instancia-ec2"
export INSTANCE_CATEGORIES="m,c,r"
export INSTANCE_CPUS="4,8,16,32"
export AVAILABILITY_ZONES="us-east-1a,us-east-1b"
export EPHEMERAL_STORAGE_SIZE="80Gi"
export CPU_LIMIT="1000"
export MEMORY_LIMIT="1000Gi"
```

---

## Scripts Disponibles

### 1. install-all-controllers.sh
**Propósito:** Script maestro que orquesta la instalación completa
**Funcionalidades:**
- Verificación de prerrequisitos
- Validación de configuración
- Instalación secuencial de componentes
- Verificación de estado
- Reporte de instalación

**Uso:**
```bash
./install-all-controllers.sh
```

### 2. install-aws-lb-controller.sh
**Propósito:** Instala AWS Load Balancer Controller
**Funcionalidades:**
- Descarga de políticas IAM
- Creación de roles y service accounts
- Configuración OIDC
- Instalación vía Helm
- Configuración automática de VPC

**Componentes instalados:**
- IAM Policy: `EKSLoadBalancerPolicy`
- IAM Role: `EKSLoadBalancerRole`
- Service Account: `aws-load-balancer-controller`
- Helm Chart: `eks/aws-load-balancer-controller`

### 3. install-nginx-ingress.sh
**Propósito:** Instala NGINX Ingress Controller
**Funcionalidades:**
- Configuración de Network Load Balancer
- Detección automática de security groups
- Configuración SSL/TLS con ACM
- Autoscaling y métricas
- Configuraciones de seguridad

**Componentes instalados:**
- Namespace: configurable (default: `ingress-nginx-ns`)
- Helm Chart: `ingress-nginx/ingress-nginx`
- Network Load Balancer con configuración AWS

### 4. deploy-nodeclass-nodepool.sh
**Propósito:** Despliega NodeClass y NodePool para EKS Auto Mode
**Funcionalidades:**
- Generación dinámica de YAML
- Configuración de tipos de instancia
- Selección de subnets y security groups
- Configuración de límites y disrupciones
- Etiquetado de instancias EC2

**Recursos creados:**
- NodeClass: configuración de nodos
- NodePool: pool de nodos con requisitos específicos

### 5. install-cluster-autoscaler.sh
**Propósito:** Instala Cluster Autoscaler (opcional)
**Funcionalidades:**
- Configuración IAM para autoscaling
- Instalación vía Helm
- Configuración de límites de escalado

### 6. uninstall-controllers.sh
**Propósito:** Desinstala todos los componentes
**Funcionalidades:**
- Eliminación de Helm releases
- Limpieza de namespaces
- Eliminación de service accounts
- Limpieza de recursos IAM

### 7. verify-installation.sh
**Propósito:** Verifica el estado de la instalación
**Funcionalidades:**
- Verificación de deployments
- Estado de pods y servicios
- Verificación de IngressClasses
- Obtención de endpoints externos

### 8. monitor-app.sh
**Propósito:** Monitorea aplicaciones desplegadas
**Funcionalidades:**
- Monitoreo en tiempo real de pods
- Verificación de servicios
- Estado de ingress

---

## Instalación

### Instalación Rápida
```bash
# 1. Clonar/descargar el proyecto
cd prueba_controladores

# 2. Configurar variables
cp config.env.example config.env
nano config.env  # Editar con tus valores

# 3. Hacer scripts ejecutables
chmod +x *.sh

# 4. Ejecutar instalación completa
./install-all-controllers.sh
```

### Instalación Selectiva
```bash
# Solo AWS Load Balancer Controller
export INSTALL_AWS_LB_CONTROLLER="true"
export INSTALL_NGINX_CONTROLLER="false"
./install-all-controllers.sh

# Solo NGINX Ingress Controller
export INSTALL_NGINX_CONTROLLER="true"
export INSTALL_AWS_LB_CONTROLLER="false"
./install-all-controllers.sh
```

### Instalación Manual por Componentes
```bash
# AWS Load Balancer Controller
./install-aws-lb-controller.sh

# NGINX Ingress Controller
./install-nginx-ingress.sh

# EKS Auto Mode NodeClass/NodePool
./deploy-nodeclass-nodepool.sh
```

---

## EKS Auto Mode

### Configuración de NodeClass
El NodeClass define la configuración base para los nodos:

```yaml
apiVersion: eks.amazonaws.com/v1
kind: NodeClass
metadata:
  name: test-customize
spec:
  role: "AUTO-MODE"
  subnetSelectorTerms:
    - tags:
        kubernetes.io/role/internal-elb: "1"
  securityGroupSelectorTerms:
    - tags:
        kubernetes.io/sg/nodes: "enabled"
  ephemeralStorage:
    size: "80Gi"
  tags:
    Name: "mi-instancia-ec2"
```

### Configuración de NodePool
El NodePool define los requisitos y límites:

```yaml
apiVersion: karpenter.sh/v1
kind: NodePool
metadata:
  name: my-node-pool
spec:
  template:
    spec:
      nodeClassRef:
        group: eks.amazonaws.com
        kind: NodeClass
        name: test-customize
      requirements:
        - key: "eks.amazonaws.com/instance-category"
          operator: In
          values: ["m", "c", "r"]
        - key: "eks.amazonaws.com/instance-cpu"
          operator: In
          values: ["4", "8", "16", "32"]
  limits:
    cpu: "1000"
    memory: 1000Gi
```

### NodeSelectors Disponibles
Para dirigir workloads a nodos específicos:

```yaml
# EKS Auto Mode
nodeSelector:
  eks.amazonaws.com/compute-type: auto

# Tipo de instancia específico
nodeSelector:
  node.kubernetes.io/instance-type: m5.large

# Zona de disponibilidad
nodeSelector:
  topology.kubernetes.io/zone: us-east-1a

# Arquitectura
nodeSelector:
  kubernetes.io/arch: amd64

# Categoría de instancia
nodeSelector:
  eks.amazonaws.com/instance-category: m
```

---

## Verificación

### Verificación Automática
```bash
./verify-installation.sh
```

### Verificación Manual
```bash
# AWS Load Balancer Controller
kubectl get deployment -n kube-system aws-load-balancer-controller
kubectl get pods -n kube-system -l app.kubernetes.io/name=aws-load-balancer-controller

# NGINX Ingress Controller
kubectl get deployment -n ingress-nginx-ns ingress-nginx-controller
kubectl get svc -n ingress-nginx-ns ingress-nginx-controller

# EKS Auto Mode
kubectl get nodeclass
kubectl get nodepool
kubectl get nodes --show-labels

# IngressClasses
kubectl get ingressclass
```

### Prueba de Funcionamiento
```bash
# Aplicar aplicación de prueba
kubectl apply -f nginx-test-app.yaml

# Verificar ingress
kubectl get ingress

# Obtener URL del Load Balancer
kubectl get svc -n ingress-nginx-ns ingress-nginx-controller \
  -o jsonpath='{.status.loadBalancer.ingress[0].hostname}'
```

---

## Troubleshooting

### Problemas Comunes

#### 1. AWS Load Balancer Controller
```bash
# Verificar logs
kubectl logs -n kube-system deployment/aws-load-balancer-controller

# Verificar service account
kubectl describe sa aws-load-balancer-controller -n kube-system

# Verificar IAM role
aws iam get-role --role-name EKSLoadBalancerRole
```

#### 2. NGINX Ingress Controller
```bash
# Verificar service
kubectl describe svc ingress-nginx-controller -n ingress-nginx-ns

# Verificar eventos
kubectl get events -n ingress-nginx-ns --sort-by='.lastTimestamp'

# Verificar Load Balancer
aws elbv2 describe-load-balancers --names mi-nlb-ingress
```

#### 3. EKS Auto Mode
```bash
# Verificar NodeClass
kubectl describe nodeclass test-customize

# Verificar NodePool
kubectl describe nodepool my-node-pool

# Verificar permisos IAM
aws iam list-attached-role-policies --role-name AUTO-MODE
```

#### 4. Permisos IAM
```bash
# Verificar identidad actual
aws sts get-caller-identity

# Verificar políticas
aws iam get-policy-version \
  --policy-arn arn:aws:iam::ACCOUNT:policy/EKSLoadBalancerPolicy \
  --version-id v1
```

### Comandos de Diagnóstico
```bash
# Estado del cluster
kubectl cluster-info
kubectl get nodes -o wide

# Recursos de red
kubectl get svc --all-namespaces
kubectl get ingress --all-namespaces

# Logs de sistema
kubectl logs -n kube-system -l k8s-app=aws-load-balancer-controller
kubectl logs -n ingress-nginx-ns -l app.kubernetes.io/name=ingress-nginx

# Eventos del cluster
kubectl get events --sort-by='.lastTimestamp' --all-namespaces
```

### Solución de Problemas de Red
```bash
# Verificar VPC y subnets
aws ec2 describe-vpcs --vpc-ids $VPC_ID
aws ec2 describe-subnets --filters "Name=vpc-id,Values=$VPC_ID"

# Verificar security groups
aws ec2 describe-security-groups --group-ids $INGRESS_SECURITY_GROUP

# Verificar route tables
aws ec2 describe-route-tables --filters "Name=vpc-id,Values=$VPC_ID"
```

---

## Seguridad

### Ofuscación de Datos Sensibles
Los scripts incluyen una función para ofuscar datos sensibles:

```bash
# Función automática en todos los scripts
mask_account_id() {
    sed "s/$AWS_ACCOUNT_ID/***masked***/g"
}
```

**Datos ofuscados:**
- AWS Account ID
- ARNs de recursos
- Contextos de kubectl
- Salidas de comandos AWS CLI

### Mejores Prácticas de Seguridad
1. **IAM Roles:** Usar roles específicos con permisos mínimos
2. **Network Security:** Configurar security groups restrictivos
3. **Encryption:** Usar certificados ACM para TLS
4. **Monitoring:** Habilitar logs y métricas
5. **Updates:** Mantener versiones actualizadas

### Configuración de Security Groups
```bash
# Security group para Load Balancer
aws ec2 create-security-group \
  --group-name eks-ingress-sg \
  --description "Security group for EKS Ingress" \
  --vpc-id $VPC_ID

# Reglas de entrada
aws ec2 authorize-security-group-ingress \
  --group-id sg-xxxxxxxxx \
  --protocol tcp \
  --port 80 \
  --cidr 0.0.0.0/0

aws ec2 authorize-security-group-ingress \
  --group-id sg-xxxxxxxxx \
  --protocol tcp \
  --port 443 \
  --cidr 0.0.0.0/0
```

---

## Costos Estimados

| Componente | Costo Mensual Aproximado |
|------------|-------------------------|
| Network Load Balancer | $16-45 USD |
| Application Load Balancer | $16-22 USD |
| Data Processing | $0.006-0.008 por GB |
| EC2 Instances (Auto Mode) | Variable según uso |
| EBS Storage | $0.10 por GB-mes |

### Optimización de Costos
1. **Spot Instances:** Usar en NodePools para cargas no críticas
2. **Autoscaling:** Configurar límites apropiados
3. **Resource Limits:** Definir requests y limits en pods
4. **Monitoring:** Usar métricas para optimizar recursos

---

## Versionado y Compatibilidad

### Versiones Soportadas
- **Kubernetes:** 1.24+
- **EKS:** 1.24+
- **AWS Load Balancer Controller:** 2.4+
- **NGINX Ingress Controller:** 1.8+
- **Helm:** 3.8+

### Matriz de Compatibilidad
| EKS Version | AWS LB Controller | NGINX Ingress | Karpenter |
|-------------|-------------------|---------------|-----------|
| 1.28 | 2.6+ | 1.9+ | 0.32+ |
| 1.27 | 2.5+ | 1.8+ | 0.31+ |
| 1.26 | 2.4+ | 1.7+ | 0.30+ |

---

## Contribución y Soporte

### Estructura de Logs
Los scripts generan logs detallados con emojis para facilitar la lectura:
- 🚀 Inicio de procesos
- ✅ Operaciones exitosas
- ❌ Errores
- ⚠️ Advertencias
- 🔍 Verificaciones
- 📦 Instalaciones
- 🔧 Configuraciones

### Reportar Problemas
1. Ejecutar `./verify-installation.sh`
2. Recopilar logs: `kubectl logs -n kube-system deployment/aws-load-balancer-controller`
3. Verificar configuración: `cat config.env`
4. Incluir versiones de herramientas

---

**Notas Importantes:**
- Todos los scripts incluyen validación de prerrequisitos
- Los datos sensibles se ofuscan automáticamente en la salida
- Los Load Balancers pueden tardar 5-10 minutos en estar disponibles
- Mantener actualizadas las versiones para seguridad y compatibilidad
- Verificar límites de AWS Service Quotas antes de la instalación