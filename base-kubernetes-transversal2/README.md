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
├── Chart.yaml                          # Metadatos del chart (generado automáticamente)
├── values.yaml                         # Valores por defecto
├── .env.ficohsa                        # Variables de ambiente con control de versiones
├── deployment.sh                       # Script de deployment automatizado
├── templates/
│   ├── Chart.yaml.template             # Template para generar Chart.yaml con versiones
│   ├── nodeclass.yaml                  # Template de NodeClass
│   ├── nodepool.yaml                   # Template de NodePool
│   ├── NOTES.txt                       # Notas post-instalación
│   └── _helpers.tpl                    # Funciones helper
├── charts/                             # Dependencias (auto-descargadas)
└── README.md                           # Este archivo

# Archivos generados al ejecutar deployment:
├── values-ficohsa.yaml                 # Valores generados con variables sustituidas
└── manifests-ficohsa/                  # Manifiestos YAML renderizados
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

### Permisos AWS
- Acceso al cluster EKS
- Permisos para crear/modificar recursos IAM
- Acceso a VPC, subnets y security groups

### IAM Roles Requeridos

#### Para EKS Cluster (Control Plane)

**Políticas AWS Managed Requeridas:**

**Para EKS Standard:**
- `AmazonEKSClusterPolicy`

**Para EKS Auto Mode (adicionales):**
- `AmazonEKSClusterPolicy`
- `AmazonEKSComputePolicy`
- `AmazonEKSBlockStoragePolicy`
- `AmazonEKSLoadBalancingPolicy`
- `AmazonEKSNetworkingPolicy`

**Trust Policy:**
```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Service": "eks.amazonaws.com"
      },
      "Action": [
        "sts:AssumeRole",
        "sts:TagSession"
      ]
    }
  ]
}
```

**Crear rol para EKS Standard:**
```bash
aws iam create-role \
  --role-name AmazonEKSClusterRole \
  --assume-role-policy-document file://cluster-trust-policy.json

aws iam attach-role-policy \
  --role-name AmazonEKSClusterRole \
  --policy-arn arn:aws:iam::aws:policy/AmazonEKSClusterPolicy
```

**Crear rol para EKS Auto Mode:**
```bash
aws iam create-role \
  --role-name AmazonEKSAutoClusterRole \
  --assume-role-policy-document file://cluster-trust-policy.json

# Adjuntar todas las políticas AWS managed para Auto Mode
aws iam attach-role-policy \
  --role-name AmazonEKSAutoClusterRole \
  --policy-arn arn:aws:iam::aws:policy/AmazonEKSClusterPolicy

aws iam attach-role-policy \
  --role-name AmazonEKSAutoClusterRole \
  --policy-arn arn:aws:iam::aws:policy/AmazonEKSComputePolicy

aws iam attach-role-policy \
  --role-name AmazonEKSAutoClusterRole \
  --policy-arn arn:aws:iam::aws:policy/AmazonEKSBlockStoragePolicy

aws iam attach-role-policy \
  --role-name AmazonEKSAutoClusterRole \
  --policy-arn arn:aws:iam::aws:policy/AmazonEKSLoadBalancingPolicy

aws iam attach-role-policy \
  --role-name AmazonEKSAutoClusterRole \
  --policy-arn arn:aws:iam::aws:policy/AmazonEKSNetworkingPolicy

# IMPORTANTE: Agregar política adicional para Launch Templates (requerida para Karpenter)
aws iam put-role-policy \
  --role-name AmazonEKSAutoClusterRole \
  --policy-name EKSAutoModeLaunchTemplatePolicy \
  --policy-document '{
    "Version": "2012-10-17",
    "Statement": [
      {
        "Effect": "Allow",
        "Action": [
          "ec2:CreateLaunchTemplate",
          "ec2:CreateLaunchTemplateVersion",
          "ec2:DescribeLaunchTemplates",
          "ec2:DescribeLaunchTemplateVersions",
          "ec2:DeleteLaunchTemplate",
          "ec2:CreateFleet",
          "ec2:RunInstances"
        ],
        "Resource": "*"
      }
    ]
  }'
```

> **⚠️ Nota Importante:** Las políticas AWS managed para EKS Auto Mode **no incluyen** todos los permisos necesarios para Karpenter. Es **obligatorio** agregar la política adicional `EKSAutoModeLaunchTemplatePolicy` para que el NodeClass funcione correctamente.

#### Para EKS Worker Nodes (Managed Node Groups)

**Políticas AWS Managed Requeridas:**
- `AmazonEKSWorkerNodePolicy`
- `AmazonEKS_CNI_Policy`
- `AmazonEC2ContainerRegistryReadOnly`

**Trust Policy:**
```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Service": "ec2.amazonaws.com"
      },
      "Action": "sts:AssumeRole"
    }
  ]
}
```

**Crear rol:**
```bash
aws iam create-role \
  --role-name AmazonEKSNodeRole \
  --assume-role-policy-document file://node-trust-policy.json

# Adjuntar políticas
aws iam attach-role-policy \
  --role-name AmazonEKSNodeRole \
  --policy-arn arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy

aws iam attach-role-policy \
  --role-name AmazonEKSNodeRole \
  --policy-arn arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy

aws iam attach-role-policy \
  --role-name AmazonEKSNodeRole \
  --policy-arn arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly
```

#### Para AWS Load Balancer Controller

**Política IAM Requerida:** `AWSLoadBalancerControllerIAMPolicy`

**Crear archivo de política (iam-policy.json):**
```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "iam:CreateServiceLinkedRole",
        "ec2:DescribeAccountAttributes",
        "ec2:DescribeAddresses",
        "ec2:DescribeAvailabilityZones",
        "ec2:DescribeInternetGateways",
        "ec2:DescribeVpcs",
        "ec2:DescribeSubnets",
        "ec2:DescribeSecurityGroups",
        "ec2:DescribeInstances",
        "ec2:DescribeNetworkInterfaces",
        "ec2:DescribeTags",
        "ec2:GetCoipPoolUsage",
        "ec2:DescribeCoipPools",
        "elasticloadbalancing:DescribeLoadBalancers",
        "elasticloadbalancing:DescribeLoadBalancerAttributes",
        "elasticloadbalancing:DescribeListeners",
        "elasticloadbalancing:DescribeListenerCertificates",
        "elasticloadbalancing:DescribeSSLPolicies",
        "elasticloadbalancing:DescribeRules",
        "elasticloadbalancing:DescribeTargetGroups",
        "elasticloadbalancing:DescribeTargetGroupAttributes",
        "elasticloadbalancing:DescribeTargetHealth",
        "elasticloadbalancing:DescribeTags"
      ],
      "Resource": "*"
    },
    {
      "Effect": "Allow",
      "Action": [
        "cognito-idp:DescribeUserPoolClient",
        "acm:ListCertificates",
        "acm:DescribeCertificate",
        "iam:ListServerCertificates",
        "iam:GetServerCertificate",
        "waf-regional:GetWebACL",
        "waf-regional:GetWebACLForResource",
        "waf-regional:AssociateWebACL",
        "waf-regional:DisassociateWebACL",
        "wafv2:GetWebACL",
        "wafv2:GetWebACLForResource",
        "wafv2:AssociateWebACL",
        "wafv2:DisassociateWebACL",
        "shield:GetSubscriptionState",
        "shield:DescribeProtection",
        "shield:CreateProtection",
        "shield:DeleteProtection"
      ],
      "Resource": "*"
    },
    {
      "Effect": "Allow",
      "Action": [
        "ec2:AuthorizeSecurityGroupIngress",
        "ec2:RevokeSecurityGroupIngress"
      ],
      "Resource": "*"
    },
    {
      "Effect": "Allow",
      "Action": [
        "ec2:CreateSecurityGroup"
      ],
      "Resource": "*"
    },
    {
      "Effect": "Allow",
      "Action": [
        "ec2:CreateTags"
      ],
      "Resource": "arn:aws:ec2:*:*:security-group/*",
      "Condition": {
        "StringEquals": {
          "ec2:CreateAction": "CreateSecurityGroup"
        },
        "Null": {
          "aws:RequestTag/elbv2.k8s.aws/cluster": "false"
        }
      }
    },
    {
      "Effect": "Allow",
      "Action": [
        "ec2:CreateTags",
        "ec2:DeleteTags"
      ],
      "Resource": "arn:aws:ec2:*:*:security-group/*",
      "Condition": {
        "Null": {
          "aws:RequestTag/elbv2.k8s.aws/cluster": "true",
          "aws:ResourceTag/elbv2.k8s.aws/cluster": "false"
        }
      }
    },
    {
      "Effect": "Allow",
      "Action": [
        "ec2:AuthorizeSecurityGroupIngress",
        "ec2:RevokeSecurityGroupIngress",
        "ec2:DeleteSecurityGroup"
      ],
      "Resource": "*",
      "Condition": {
        "Null": {
          "aws:ResourceTag/elbv2.k8s.aws/cluster": "false"
        }
      }
    },
    {
      "Effect": "Allow",
      "Action": [
        "elasticloadbalancing:CreateLoadBalancer",
        "elasticloadbalancing:CreateTargetGroup"
      ],
      "Resource": "*",
      "Condition": {
        "Null": {
          "aws:RequestTag/elbv2.k8s.aws/cluster": "false"
        }
      }
    },
    {
      "Effect": "Allow",
      "Action": [
        "elasticloadbalancing:CreateListener",
        "elasticloadbalancing:DeleteListener",
        "elasticloadbalancing:CreateRule",
        "elasticloadbalancing:DeleteRule"
      ],
      "Resource": "*"
    },
    {
      "Effect": "Allow",
      "Action": [
        "elasticloadbalancing:AddTags",
        "elasticloadbalancing:RemoveTags"
      ],
      "Resource": [
        "arn:aws:elasticloadbalancing:*:*:targetgroup/*/*",
        "arn:aws:elasticloadbalancing:*:*:loadbalancer/net/*/*",
        "arn:aws:elasticloadbalancing:*:*:loadbalancer/app/*/*"
      ],
      "Condition": {
        "Null": {
          "aws:RequestTag/elbv2.k8s.aws/cluster": "true",
          "aws:ResourceTag/elbv2.k8s.aws/cluster": "false"
        }
      }
    },
    {
      "Effect": "Allow",
      "Action": [
        "elasticloadbalancing:AddTags",
        "elasticloadbalancing:RemoveTags"
      ],
      "Resource": [
        "arn:aws:elasticloadbalancing:*:*:listener/net/*/*/*",
        "arn:aws:elasticloadbalancing:*:*:listener/app/*/*/*",
        "arn:aws:elasticloadbalancing:*:*:listener-rule/net/*/*/*",
        "arn:aws:elasticloadbalancing:*:*:listener-rule/app/*/*/*"
      ]
    },
    {
      "Effect": "Allow",
      "Action": [
        "elasticloadbalancing:ModifyLoadBalancerAttributes",
        "elasticloadbalancing:SetIpAddressType",
        "elasticloadbalancing:SetSecurityGroups",
        "elasticloadbalancing:SetSubnets",
        "elasticloadbalancing:DeleteLoadBalancer",
        "elasticloadbalancing:ModifyTargetGroup",
        "elasticloadbalancing:ModifyTargetGroupAttributes",
        "elasticloadbalancing:DeleteTargetGroup"
      ],
      "Resource": "*",
      "Condition": {
        "Null": {
          "aws:ResourceTag/elbv2.k8s.aws/cluster": "false"
        }
      }
    },
    {
      "Effect": "Allow",
      "Action": [
        "elasticloadbalancing:RegisterTargets",
        "elasticloadbalancing:DeregisterTargets"
      ],
      "Resource": "arn:aws:elasticloadbalancing:*:*:targetgroup/*/*"
    },
    {
      "Effect": "Allow",
      "Action": [
        "elasticloadbalancing:SetWebAcl",
        "elasticloadbalancing:ModifyListener",
        "elasticloadbalancing:AddListenerCertificates",
        "elasticloadbalancing:RemoveListenerCertificates",
        "elasticloadbalancing:ModifyRule"
      ],
      "Resource": "*"
    }
  ]
}
```

**Crear política:**
```bash
aws iam create-policy \
  --policy-name AWSLoadBalancerControllerIAMPolicy \
  --policy-document file://iam-policy.json
```

**Trust Policy (OIDC):**
```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Federated": "arn:aws:iam::ACCOUNT-ID:oidc-provider/oidc.eks.REGION.amazonaws.com/id/EXAMPLED539D4633E53DE1B71EXAMPLE"
      },
      "Action": "sts:AssumeRoleWithWebIdentity",
      "Condition": {
        "StringEquals": {
          "oidc.eks.REGION.amazonaws.com/id/EXAMPLED539D4633E53DE1B71EXAMPLE:sub": "system:serviceaccount:kube-system:aws-load-balancer-controller",
          "oidc.eks.REGION.amazonaws.com/id/EXAMPLED539D4633E53DE1B71EXAMPLE:aud": "sts.amazonaws.com"
        }
      }
    }
  ]
}
```

**Crear rol:**
```bash
aws iam create-role \
  --role-name AmazonEKSLoadBalancerControllerRole \
  --assume-role-policy-document file://trust-policy.json

aws iam attach-role-policy \
  --role-name AmazonEKSLoadBalancerControllerRole \
  --policy-arn arn:aws:iam::ACCOUNT-ID:policy/AWSLoadBalancerControllerIAMPolicy
```

#### Para Cluster Autoscaler

**Política IAM Requerida:**
```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "autoscaling:DescribeAutoScalingGroups",
        "autoscaling:DescribeAutoScalingInstances",
        "autoscaling:DescribeLaunchConfigurations",
        "autoscaling:DescribeTags",
        "autoscaling:SetDesiredCapacity",
        "autoscaling:TerminateInstanceInAutoScalingGroup",
        "ec2:DescribeLaunchTemplateVersions",
        "ec2:DescribeInstanceTypes"
      ],
      "Resource": "*"
    }
  ]
}
```

**Trust Policy (OIDC):**
```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Federated": "arn:aws:iam::ACCOUNT-ID:oidc-provider/oidc.eks.REGION.amazonaws.com/id/EXAMPLED539D4633E53DE1B71EXAMPLE"
      },
      "Action": "sts:AssumeRoleWithWebIdentity",
      "Condition": {
        "StringEquals": {
          "oidc.eks.REGION.amazonaws.com/id/EXAMPLED539D4633E53DE1B71EXAMPLE:sub": "system:serviceaccount:kube-system:cluster-autoscaler",
          "oidc.eks.REGION.amazonaws.com/id/EXAMPLED539D4633E53DE1B71EXAMPLE:aud": "sts.amazonaws.com"
        }
      }
    }
  ]
}
```

**Crear rol:**
```bash
aws iam create-policy \
  --policy-name AmazonEKSClusterAutoscalerPolicy \
  --policy-document file://cluster-autoscaler-policy.json

aws iam create-role \
  --role-name AmazonEKSClusterAutoscalerRole \
  --assume-role-policy-document file://trust-policy.json

aws iam attach-role-policy \
  --role-name AmazonEKSClusterAutoscalerRole \
  --policy-arn arn:aws:iam::ACCOUNT-ID:policy/AmazonEKSClusterAutoscalerPolicy
```

#### Para Karpenter (EKS Auto Mode)

**Políticas AWS Managed Requeridas:**
- `AmazonEKSWorkerNodePolicy`
- `AmazonEKS_CNI_Policy`
- `AmazonEC2ContainerRegistryReadOnly`

**Trust Policy:**
```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Service": "ec2.amazonaws.com"
      },
      "Action": "sts:AssumeRole"
    }
  ]
}
```

**Crear rol:**
```bash
aws iam create-role \
  --role-name Banco-Ficohsa-Iam-Role-AUTO-MODE \
  --assume-role-policy-document file://trust-policy.json

# Adjuntar políticas
aws iam attach-role-policy \
  --role-name Banco-Ficohsa-Iam-Role-AUTO-MODE \
  --policy-arn arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy

aws iam attach-role-policy \
  --role-name Banco-Ficohsa-Iam-Role-AUTO-MODE \
  --policy-arn arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy

aws iam attach-role-policy \
  --role-name Banco-Ficohsa-Iam-Role-AUTO-MODE \
  --policy-arn arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly
```

### Configuración OIDC Provider

Para usar IAM Roles for Service Accounts (IRSA):

```bash
eksctl utils associate-iam-oidc-provider \
  --region us-east-1 \
  --cluster your-cluster-name \
  --approve
```

## 🛠 Instalación

### 1. Clonar el Repositorio
```bash
git clone <repository-url>
cd eks-controllers
```

### 2. Configurar Variables de Ambiente
Edita el archivo `.env.dev` o `.env.prod` según tu ambiente:

```bash
# Ejemplo para desarrollo
cp .env.dev .env.dev.local
vim .env.dev.local
```

### 3. Deployment Automatizado
```bash
# Para desarrollo
./deployment.sh dev

# Para producción
./deployment.sh prod
```

### 4. Deployment Manual (Opcional)
```bash
# Actualizar dependencias
helm dependency update

# Instalar
helm install eks-controllers . -f values-dev.yaml -n kube-system
```

## ⚙️ Configuración

### Control de Versiones de Controladores

El proyecto permite controlar las versiones de los controladores directamente desde el archivo `.env.ficohsa`:

```bash
# =====================================================
# VERSIONES DE CONTROLADORES
# =====================================================
export LB_CONTROLLER_VERSION=1.16.0      # AWS Load Balancer Controller
export CLUSTER_AUTOSCALER_VERSION=9.54.0 # Cluster Autoscaler
```

**Cómo funciona:**
1. Las variables se definen en `.env.ficohsa`
2. El script `deployment.sh` genera `Chart.yaml` usando `templates/Chart.yaml.template`
3. Helm descarga automáticamente las versiones especificadas

**Versiones disponibles:**
```bash
# Ver versiones del Load Balancer Controller
helm search repo eks/aws-load-balancer-controller --versions

# Ver versiones del Cluster Autoscaler
helm search repo autoscaler/cluster-autoscaler --versions
```

### Configuración por Ambiente

El proyecto soporta múltiples ambientes mediante archivos `.env.*`:

- **`.env.dev`** - Desarrollo
- **`.env.prod`** - Producción

### Habilitar/Deshabilitar Componentes

En el archivo `.env.*` correspondiente:

```bash
# AWS Load Balancer Controller
LB_CONTROLLER_ENABLED=true

# Cluster Autoscaler
CLUSTER_AUTOSCALER_ENABLED=true

# Karpenter NodeClass
NODECLASS_ENABLED=true

# Karpenter NodePool
NODEPOOL_ENABLED=true
```

### Configuración de Karpenter

Para configurar Karpenter, edita las variables en `.env.*`:

```bash
# NodeClass
NODECLASS_ROLE=Banco-Ficohsa-Iam-Role-AUTO-MODE
NODECLASS_SUBNET_IDS=subnet-123,subnet-456,subnet-789
NODECLASS_SG_IDS=sg-123456789

# NodePool
NODEPOOL_INSTANCE_CATEGORIES=c,m,r
NODEPOOL_CAPACITY_TYPES=spot,on-demand
NODEPOOL_CPU_LIMIT=1000
NODEPOOL_MEMORY_LIMIT=1000Gi
```

## 🚀 Uso

### Deployment Básico
```bash
# Ejecutar deployment completo
./deployment.sh ficohsa
```

Este comando ejecuta automáticamente:
1. ✅ **Carga variables** del archivo `.env.ficohsa`
2. ✅ **Genera Chart.yaml** con las versiones especificadas
3. ✅ **Genera values-ficohsa.yaml** con valores sustituidos
4. ✅ **Crea manifests-ficohsa/** con YAMLs renderizados
5. ✅ **Actualiza dependencias** de Helm con las versiones correctas
6. ✅ **Despliega o actualiza** el release en Kubernetes
7. ✅ **Verifica** el estado del deployment

### Cambiar Versiones de Controladores
```bash
# 1. Editar versiones en .env.ficohsa
vim .env.ficohsa

# 2. Cambiar las versiones deseadas
export LB_CONTROLLER_VERSION=1.15.0
export CLUSTER_AUTOSCALER_VERSION=9.53.0

# 3. Redesplegar
./deployment.sh ficohsa
```

### Verificar Deployment
```bash
# Ver todos los recursos
kubectl get all -n kube-system

# Ver recursos de Karpenter
kubectl get nodeclass
kubectl get nodepool
kubectl get nodes -l karpenter.sh/nodepool

# Ver logs de controladores
kubectl logs -n kube-system -l app.kubernetes.io/name=aws-load-balancer-controller
kubectl logs -n kube-system -l app.kubernetes.io/name=aws-cluster-autoscaler
```

### Actualizar Configuración
```bash
# Editar variables
vim .env.dev

# Redesplegar
./deployment.sh dev
```

### Eliminar Deployment
```bash
# Eliminar release
helm uninstall eks-controllers-dev -n kube-system

# Limpiar recursos de Karpenter (si es necesario)
kubectl delete nodepool --all
kubectl delete nodeclass --all
```

## 📝 Variables de Ambiente

### Variables de Control de Versiones
| Variable | Descripción | Ejemplo |
|----------|-------------|---------|
| `LB_CONTROLLER_VERSION` | Versión del chart AWS Load Balancer Controller | `1.16.0` |
| `CLUSTER_AUTOSCALER_VERSION` | Versión del chart Cluster Autoscaler | `9.54.0` |

### Variables Globales
| Variable | Descripción | Ejemplo |
|----------|-------------|---------|
| `CLUSTER_NAME` | Nombre del cluster EKS | `mi-cluster` |
| `AWS_REGION` | Región de AWS | `us-east-1` |
| `AWS_ACCOUNT_ID` | ID de cuenta AWS | `123456789012` |
| `VPC_ID` | ID de la VPC | `vpc-123456789` |

### AWS Load Balancer Controller
| Variable | Descripción | Default |
|----------|-------------|---------|
| `LB_CONTROLLER_ENABLED` | Habilitar controlador | `true` |
| `LB_CONTROLLER_REPLICAS` | Número de réplicas | `2` |
| `LB_CONTROLLER_ROLE_ARN` | ARN del IAM role | - |

### Cluster Autoscaler
| Variable | Descripción | Default |
|----------|-------------|---------|
| `CLUSTER_AUTOSCALER_ENABLED` | Habilitar autoscaler | `false` |
| `CLUSTER_AUTOSCALER_REPLICAS` | Número de réplicas | `1` |
| `CA_SCALE_DOWN_ENABLED` | Permitir scale down | `true` |

### Karpenter NodeClass
| Variable | Descripción | Ejemplo |
|----------|-------------|---------|
| `NODECLASS_ENABLED` | Habilitar NodeClass | `true` |
| `NODECLASS_ROLE` | IAM role para nodos | `eks-node-role` |
| `NODECLASS_SUBNET_IDS` | Subnets (separadas por comas) | `subnet-123,subnet-456` |
| `NODECLASS_SG_IDS` | Security groups | `sg-123456789` |

### Karpenter NodePool
| Variable | Descripción | Ejemplo |
|----------|-------------|---------|
| `NODEPOOL_ENABLED` | Habilitar NodePool | `true` |
| `NODEPOOL_INSTANCE_CATEGORIES` | Categorías de instancias | `c,m,r` |
| `NODEPOOL_CAPACITY_TYPES` | Tipos de capacidad | `spot,on-demand` |
| `NODEPOOL_CPU_LIMIT` | Límite de CPU | `1000` |

Ver documentación completa en:
- [NODECLASS-DOCUMENTATION.md](./NODECLASS-DOCUMENTATION.md)
- [NODEPOOL-DOCUMENTATION.md](./NODEPOOL-DOCUMENTATION.md)

## 🔧 Comandos Útiles

### Verificación de Estado
```bash
# Estado general
kubectl get pods -n kube-system -o wide

# Recursos de Karpenter
kubectl get nodeclass -o wide
kubectl get nodepool -o wide
kubectl get nodes -l karpenter.sh/nodepool -o wide

# Describir recursos
kubectl describe nodeclass <name>
kubectl describe nodepool <name>
```

### Logs y Debug
```bash
# Logs del Load Balancer Controller
kubectl logs -n kube-system -l app.kubernetes.io/name=aws-load-balancer-controller -f

# Logs del Cluster Autoscaler
kubectl logs -n kube-system -l app.kubernetes.io/name=aws-cluster-autoscaler -f

# Eventos del cluster
kubectl get events --sort-by=.metadata.creationTimestamp
```

### Helm Operations
```bash
# Ver releases instalados
helm list -n kube-system

# Ver historial de releases
helm history eks-controllers-dev -n kube-system

# Rollback
helm rollback eks-controllers-dev 1 -n kube-system

# Ver valores aplicados
helm get values eks-controllers-dev -n kube-system
```

## 🐛 Troubleshooting

### Problemas Comunes

#### 1. Error de Permisos IAM
```bash
# Verificar roles
aws iam get-role --role-name <role-name>
aws iam list-attached-role-policies --role-name <role-name>
```

#### 2. NodeClass/NodePool no se crean o están en Ready: False
```bash
# Verificar que Karpenter esté instalado
kubectl get pods -n karpenter

# Verificar CRDs
kubectl get crd | grep karpenter

# Describir el NodeClass para ver errores específicos
kubectl describe nodeclass <name>

# Errores comunes y soluciones:
```

**Error: "Role X is unauthorized to join nodes to the cluster"**
- Verificar que el rol de nodos tenga las políticas: `AmazonEKSWorkerNodePolicy`, `AmazonEKS_CNI_Policy`, `AmazonEC2ContainerRegistryReadOnly`
- Verificar que el rol esté en los access entries del cluster:
```bash
aws eks list-access-entries --cluster-name <cluster-name>
aws eks create-access-entry --cluster-name <cluster-name> --principal-arn <role-arn>
```

**Error: "Awaiting Instance Profile, Security Group, and Subnet resolution"**
- Verificar que el rol del cluster tenga la política adicional `EKSAutoModeLaunchTemplatePolicy`
- Las políticas AWS managed para Auto Mode **no incluyen** todos los permisos necesarios para Karpenter

#### 3. Pods no se programan en nodos Karpenter
```bash
# Verificar requirements del NodePool
kubectl describe nodepool <name>

# Verificar eventos
kubectl get events --field-selector reason=FailedScheduling
```

#### 4. Controladores no evitan nodos Karpenter
```bash
# Verificar nodeAffinity
kubectl get deployment aws-load-balancer-controller -n kube-system -o yaml | grep -A 10 affinity
```

### Logs de Debug

#### Habilitar logs detallados
En `.env.*`:
```bash
# Cluster Autoscaler (más verboso)
CA_LOG_LEVEL=6

# Load Balancer Controller (más verboso)
LB_CONTROLLER_LOG_LEVEL=debug
```

### Validación de Configuración

#### Verificar sintaxis YAML
```bash
# Validar archivo generado
helm template . -f values-dev.yaml --debug
```

#### Dry-run
```bash
# Simular instalación
helm install eks-controllers . -f values-dev.yaml -n kube-system --dry-run
```

## 📚 Referencias

- [AWS Load Balancer Controller](https://kubernetes-sigs.github.io/aws-load-balancer-controller/)
- [Cluster Autoscaler](https://github.com/kubernetes/autoscaler/tree/master/cluster-autoscaler)
- [Karpenter Documentation](https://karpenter.sh/)
- [EKS Auto Mode](https://docs.aws.amazon.com/eks/latest/userguide/auto-mode.html)
- [Helm Documentation](https://helm.sh/docs/)

## 🤝 Contribución

1. Fork el repositorio
2. Crea una rama para tu feature (`git checkout -b feature/nueva-funcionalidad`)
3. Commit tus cambios (`git commit -am 'Agregar nueva funcionalidad'`)
4. Push a la rama (`git push origin feature/nueva-funcionalidad`)
5. Crea un Pull Request

## 📄 Licencia

Este proyecto está bajo la licencia MIT. Ver el archivo `LICENSE` para más detalles.

---

**Desarrollado por:** Equipo de Platform Engineering  
**Última actualización:** Diciembre 2025
