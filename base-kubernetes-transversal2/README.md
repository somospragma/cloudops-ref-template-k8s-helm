# EKS Controllers - Helm Chart

Helm chart para desplegar controladores de EKS y recursos de Karpenter de forma automatizada y reutilizable.

## 📋 Tabla de Contenidos

- [Componentes](#componentes)
- [Estructura del Proyecto](#estructura-del-proyecto)
- [Prerequisitos](#prerequisitos)
- [Instalación](#instalación)
- [Configuración](#configuración)
- [Uso](#uso)
- [Variables de Ambiente](#variables-de-ambiente)
- [Comandos Útiles](#comandos-útiles)
- [Troubleshooting](#troubleshooting)

## 🚀 Componentes

Este chart despliega los siguientes componentes:

### Controladores AWS
- **AWS Load Balancer Controller** - Gestión de ALB/NLB
- **Cluster Autoscaler** - Escalado automático de nodos

### Karpenter (Opcional)
- **NodeClass** - Configuración de nodos EC2
- **NodePool** - Pool de nodos para workloads

## 📁 Estructura del Proyecto

```
eks-controllers/
├── Chart.yaml                          # Metadatos del chart
├── values.yaml                         # Template de valores base
├── .env.ficohsa                        # Variables con placeholders
├── deployment.sh                       # Script de deployment automatizado
├── templates/
│   ├── nodeclass.yaml                  # Template de NodeClass
│   ├── nodepool.yaml                   # Template de NodePool
│   ├── NOTES.txt                       # Notas post-instalación
│   └── _helpers.tpl                    # Funciones helper
├── charts/                             # Dependencias (auto-descargadas)
└── README.md                           # Este archivo

# Archivos generados al ejecutar deployment:
├── values-{nombre}.yaml                # Valores generados con variables sustituidas
└── manifests-{nombre}/                 # Manifiestos YAML renderizados
```

## 📋 Prerequisitos

### Software Requerido
- **kubectl** (v1.16+) - Cliente de Kubernetes
- **helm** (v3.0+) - Gestor de paquetes de Kubernetes
- **aws-cli** (v2.0+) - Cliente de AWS
- **Karpenter** (v0.32+) - Solo si se van a usar NodeClass/NodePool

### Configuración Inicial Requerida

#### 1. AWS CLI Configurado
```bash
aws configure
# O usar variables de ambiente:
export AWS_ACCESS_KEY_ID=your-access-key
export AWS_SECRET_ACCESS_KEY=your-secret-key
export AWS_DEFAULT_REGION=us-east-1
```

#### 2. Kubeconfig del Cluster
```bash
aws eks update-kubeconfig --region us-east-1 --name your-cluster-name
```

#### 3. Repositorios de Helm
```bash
helm repo add eks https://aws.github.io/eks-charts
helm repo add autoscaler https://kubernetes.github.io/autoscaler
helm repo update
```

#### 4. Karpenter Instalado (Opcional)
Si planeas usar NodeClass/NodePool:
```bash
# Verificar que Karpenter esté instalado
kubectl get pods -n karpenter

# Verificar CRDs disponibles
kubectl get crd | grep karpenter
```

## 🔧 Configuración

### 1. Configurar Variables
Edita el archivo `.env.ficohsa` con los valores específicos de tu cluster:

```bash
# Configuración del cluster
CLUSTER_NAME="${cluster_name}"           # Nombre de tu cluster EKS
AWS_REGION="${aws_region}"               # Región AWS
AWS_ACCOUNT_ID="${aws_account_id}"       # ID de cuenta AWS
VPC_ID="${vpc_id}"                       # VPC ID del cluster

# Karpenter NodeClass
NODECLASS_ROLE="${nodeclass_role}"       # IAM Role para nodos
NODECLASS_SUBNET_IDS="${nodeclass_subnet_ids}"  # Subnets separadas por comas
NODECLASS_SG_IDS="${nodeclass_sg_ids}"   # Security Groups separados por comas

# Load Balancer Controller
LB_CONTROLLER_ROLE_ARN="${lb_controller_role_arn}"  # IAM Role ARN

# Cluster Autoscaler
CLUSTER_AUTOSCALER_ROLE_ARN="${cluster_autoscaler_role_arn}"  # IAM Role ARN
```

### 2. Obtener Información del Cluster
```bash
# Obtener VPC ID
aws eks describe-cluster --name tu-cluster --query 'cluster.resourcesVpcConfig.vpcId' --output text

# Obtener Subnets
aws eks describe-cluster --name tu-cluster --query 'cluster.resourcesVpcConfig.subnetIds' --output text

# Obtener Security Groups
aws eks describe-cluster --name tu-cluster --query 'cluster.resourcesVpcConfig.securityGroupIds' --output text
```

## 🚀 Uso

### Deployment Básico
```bash
# Ejecutar deployment completo
./deployment.sh ficohsa
```

Este comando:
1. ✅ Carga las variables del archivo `.env.ficohsa`
2. ✅ Genera `values-ficohsa.yaml` con valores sustituidos
3. ✅ Crea `manifests-ficohsa/` con YAMLs renderizados
4. ✅ Actualiza dependencias de Helm
5. ✅ Despliega o actualiza el release en Kubernetes
6. ✅ Verifica el estado del deployment

### Comandos Manuales de Helm

#### Instalación
```bash
helm install eks-controllers-ficohsa . \
  --namespace kube-system \
  --values values-ficohsa.yaml \
  --create-namespace
```

#### Actualización
```bash
helm upgrade eks-controllers-ficohsa . \
  --namespace kube-system \
  --values values-ficohsa.yaml
```

#### Desinstalación
```bash
helm uninstall eks-controllers-ficohsa --namespace kube-system
```

## 📊 Variables de Ambiente

### Variables Principales

| Variable | Descripción | Ejemplo |
|----------|-------------|---------|
| `CLUSTER_NAME` | Nombre del cluster EKS | `mi-cluster-eks` |
| `AWS_REGION` | Región AWS | `us-east-1` |
| `AWS_ACCOUNT_ID` | ID de cuenta AWS | `123456789012` |
| `VPC_ID` | VPC del cluster | `vpc-0123456789abcdef0` |

### Variables de Karpenter

| Variable | Descripción | Ejemplo |
|----------|-------------|---------|
| `NODECLASS_ENABLED` | Habilitar NodeClass | `true` |
| `NODECLASS_ROLE` | IAM Role para nodos | `KarpenterNodeRole` |
| `NODECLASS_SUBNET_IDS` | Subnets (separadas por comas) | `subnet-123,subnet-456` |
| `NODECLASS_SG_IDS` | Security Groups (separados por comas) | `sg-123,sg-456` |
| `NODEPOOL_ENABLED` | Habilitar NodePool | `true` |
| `NODEPOOL_CPU_LIMIT` | Límite de CPU | `1000` |
| `NODEPOOL_MEMORY_LIMIT` | Límite de memoria | `1000Gi` |

### Variables de Load Balancer Controller

| Variable | Descripción | Ejemplo |
|----------|-------------|---------|
| `LB_CONTROLLER_ENABLED` | Habilitar controlador | `true` |
| `LB_CONTROLLER_ROLE_ARN` | IAM Role ARN | `arn:aws:iam::123:role/LBCRole` |
| `LB_CONTROLLER_REPLICAS` | Número de réplicas | `2` |
| `LB_CONTROLLER_LOG_LEVEL` | Nivel de logs | `info` |

### Variables de Cluster Autoscaler

| Variable | Descripción | Ejemplo |
|----------|-------------|---------|
| `CLUSTER_AUTOSCALER_ENABLED` | Habilitar autoscaler | `true` |
| `CLUSTER_AUTOSCALER_ROLE_ARN` | IAM Role ARN | `arn:aws:iam::123:role/CARole` |
| `CA_SCALE_DOWN_ENABLED` | Permitir reducir nodos | `true` |
| `CA_SCALE_DOWN_DELAY_AFTER_ADD` | Delay después de agregar | `1m` |

## 🛠️ Comandos Útiles

### Verificar Estado
```bash
# Estado del release
helm status eks-controllers-ficohsa -n kube-system

# Pods de los controladores
kubectl get pods -n kube-system -l app.kubernetes.io/name=aws-load-balancer-controller
kubectl get pods -n kube-system -l app.kubernetes.io/name=cluster-autoscaler

# Recursos de Karpenter
kubectl get nodeclass
kubectl get nodepool
```

### Logs
```bash
# Logs del Load Balancer Controller
kubectl logs -n kube-system -l app.kubernetes.io/name=aws-load-balancer-controller

# Logs del Cluster Autoscaler
kubectl logs -n kube-system -l app.kubernetes.io/name=cluster-autoscaler

# Logs de Karpenter
kubectl logs -n karpenter -l app.kubernetes.io/name=karpenter
```

### Debugging
```bash
# Ver manifiestos generados
ls -la manifests-ficohsa/

# Ver valores aplicados
cat values-ficohsa.yaml

# Verificar configuración
helm get values eks-controllers-ficohsa -n kube-system
```

## 🔍 Troubleshooting

### Problemas Comunes

#### 1. Error: "no matches for kind NodeClass"
```bash
# Verificar que Karpenter esté instalado
kubectl get crd | grep karpenter

# Si no está instalado, instalar Karpenter primero
```

#### 2. Error: "IAM role not found"
```bash
# Verificar que los roles IAM existan
aws iam get-role --role-name tu-role-name

# Verificar permisos del rol
aws iam list-attached-role-policies --role-name tu-role-name
```

#### 3. Error: "subnet not found"
```bash
# Verificar que las subnets existan y sean accesibles
aws ec2 describe-subnets --subnet-ids subnet-123456789
```

#### 4. Pods en estado Pending
```bash
# Verificar recursos disponibles
kubectl describe nodes

# Verificar eventos del cluster
kubectl get events --sort-by=.metadata.creationTimestamp
```

### Logs de Debugging
```bash
# Habilitar logs detallados en Load Balancer Controller
# Cambiar LB_CONTROLLER_LOG_LEVEL=debug en .env.ficohsa

# Habilitar logs detallados en Cluster Autoscaler  
# Cambiar CA_LOG_LEVEL=6 en .env.ficohsa
```

## 📚 Documentación Adicional

- [AWS Load Balancer Controller](https://kubernetes-sigs.github.io/aws-load-balancer-controller/)
- [Cluster Autoscaler](https://github.com/kubernetes/autoscaler/tree/master/cluster-autoscaler)
- [Karpenter](https://karpenter.sh/)
- [Helm Charts](https://helm.sh/docs/)

## 🤝 Contribución

1. Fork el proyecto
2. Crea una rama para tu feature (`git checkout -b feature/nueva-funcionalidad`)
3. Commit tus cambios (`git commit -am 'Agregar nueva funcionalidad'`)
4. Push a la rama (`git push origin feature/nueva-funcionalidad`)
5. Crea un Pull Request

## 📄 Licencia

Este proyecto está bajo la Licencia MIT - ver el archivo [LICENSE](LICENSE) para detalles.

---

**Nota**: Este chart está diseñado para ser reutilizable y configurable mediante variables de ambiente, facilitando el deployment en múltiples clusters y ambientes.
