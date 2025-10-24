#!/bin/bash

set -e

# Cargar variables
if [ ! -f "config.env" ]; then
    echo "❌ Archivo config.env no encontrado"
    exit 1
fi
source config.env

echo "🚀 Instalando NGINX Ingress Controller..."

# Usar namespace por defecto o el configurado
NAMESPACE=${NGINX_NAMESPACE:-ingress-nginx}

# 1. Agregar repositorio Helm de NGINX
echo "📦 Agregando repositorio Helm de NGINX..."
helm repo add ingress-nginx https://kubernetes.github.io/ingress-nginx
helm repo update

# 2. Crear namespace
echo "📁 Creando namespace $NAMESPACE..."
kubectl create namespace $NAMESPACE --dry-run=client -o yaml | kubectl apply -f -
kubectl label namespace $NAMESPACE created-by=nginx-install-script --overwrite

# 3. Crear archivo de valores personalizado
echo "📝 Creando configuración personalizada..."

# Buscar security group del cluster EKS automáticamente
echo "🔍 Buscando security group del cluster EKS..."

# Intentar múltiples patrones de búsqueda
CLUSTER_SG=$(aws ec2 describe-security-groups \
    --filters "Name=tag:aws:eks:cluster-name,Values=$CLUSTER_NAME" \
    --query 'SecurityGroups[?contains(GroupName, `ClusterSharedNodeSecurityGroup`) || contains(GroupName, `eks-cluster-sg`) || contains(Description, `EKS created security group`)].GroupId' \
    --output text \
    --profile $AWS_PROFILE 2>/dev/null | head -1)

# Si no encuentra, buscar por descripción
if [ -z "$CLUSTER_SG" ] || [ "$CLUSTER_SG" = "None" ]; then
    CLUSTER_SG=$(aws ec2 describe-security-groups \
        --filters "Name=vpc-id,Values=$VPC_ID" "Name=description,Values=*EKS*$CLUSTER_NAME*" \
        --query 'SecurityGroups[0].GroupId' \
        --output text \
        --profile $AWS_PROFILE 2>/dev/null)
fi

# Si aún no encuentra, buscar por tag del cluster
if [ -z "$CLUSTER_SG" ] || [ "$CLUSTER_SG" = "None" ]; then
    CLUSTER_SG=$(aws ec2 describe-security-groups \
        --filters "Name=tag:kubernetes.io/cluster/$CLUSTER_NAME,Values=owned" \
        --query 'SecurityGroups[0].GroupId' \
        --output text \
        --profile $AWS_PROFILE 2>/dev/null)
fi

# Combinar security groups
if [ ! -z "$CLUSTER_SG" ] && [ "$CLUSTER_SG" != "None" ]; then
    if [ ! -z "$INGRESS_SECURITY_GROUP" ]; then
        COMBINED_SG="$INGRESS_SECURITY_GROUP,$CLUSTER_SG"
    else
        COMBINED_SG="$CLUSTER_SG"
    fi
    echo "✅ Security groups: $COMBINED_SG"
else
    COMBINED_SG="$INGRESS_SECURITY_GROUP"
    echo "⚠️ No se encontró security group del cluster, usando solo: $COMBINED_SG"
fi

# Seleccionar subnets según tipo
if [ "$SUBNET_TYPE" = "private" ]; then
    SELECTED_SUBNETS="$PRIVATE_SUBNETS"
    LB_SCHEME="internal"
else
    SELECTED_SUBNETS="$PUBLIC_SUBNETS"
    LB_SCHEME="internet-facing"
fi

# Preparar anotación de certificado ACM si está configurado
ACM_ANNOTATION=""
if [ ! -z "$ACM_CERTIFICATE_ARN" ] && [ "$ACM_CERTIFICATE_ARN" != "" ]; then
    ACM_ANNOTATION="      service.beta.kubernetes.io/aws-load-balancer-ssl-cert: \"$ACM_CERTIFICATE_ARN\""
    echo "🔒 Usando certificado ACM: $ACM_CERTIFICATE_ARN"
else
    echo "ℹ️ No se configuró certificado ACM, usando HTTP"
fi

cat > nginx-values.yaml << EOF
controller:
  replicaCount: 2
  
  service:
    type: LoadBalancer
    annotations:
      service.beta.kubernetes.io/aws-load-balancer-type: "nlb"
      service.beta.kubernetes.io/aws-load-balancer-name: "$NLB_NAME"
      service.beta.kubernetes.io/aws-load-balancer-scheme: "$LB_SCHEME"
      service.beta.kubernetes.io/aws-load-balancer-subnets: "$SELECTED_SUBNETS"
      service.beta.kubernetes.io/aws-load-balancer-security-groups: "$COMBINED_SG"
      service.beta.kubernetes.io/aws-load-balancer-nlb-target-type: "$TARGET_TYPE"
      service.beta.kubernetes.io/aws-load-balancer-cross-zone-load-balancing-enabled: "true"
      service.beta.kubernetes.io/aws-load-balancer-backend-protocol: "tcp"
      service.beta.kubernetes.io/aws-load-balancer-connection-idle-timeout: "60"
$ACM_ANNOTATION
  
  resources:
    requests:
      cpu: 100m
      memory: 90Mi
    limits:
      cpu: 500m
      memory: 512Mi
  
  autoscaling:
    enabled: true
    minReplicas: 2
    maxReplicas: 10
    targetCPUUtilizationPercentage: 80
  
  metrics:
    enabled: true
    serviceMonitor:
      enabled: false  # Cambiar a true si tienes Prometheus Operator
  
  podSecurityContext:
    fsGroup: 2000
    runAsNonRoot: true
    runAsUser: 1000
  
  # Configuraciones adicionales de seguridad
  securityContext:
    allowPrivilegeEscalation: false
    capabilities:
      drop:
      - ALL
      add:
      - NET_BIND_SERVICE
    readOnlyRootFilesystem: true
    runAsNonRoot: true
    runAsUser: 1000

  # Configuración de ingress class
  ingressClassResource:
    name: nginx
    enabled: true
    default: false
    controllerValue: "k8s.io/ingress-nginx"

# Configuración del admission webhook
admissionWebhooks:
  enabled: true
  patch:
    enabled: true
EOF

# 4. Instalar NGINX Ingress Controller
echo "⚙️ Instalando NGINX Ingress Controller..."
helm install ingress-nginx ingress-nginx/ingress-nginx \
    --namespace $NAMESPACE \
    --values nginx-values.yaml \
    --version ${NGINX_CONTROLLER_VERSION:-4.8.3}

# 5. Esperar a que el deployment esté listo
echo "⏳ Esperando a que NGINX Ingress esté listo..."
kubectl wait --for=condition=available --timeout=300s deployment/ingress-nginx-controller -n $NAMESPACE

# 6. Esperar a que el LoadBalancer obtenga una IP externa
echo "🌐 Esperando a que el LoadBalancer obtenga una IP externa..."
timeout=300
counter=0
while [ $counter -lt $timeout ]; do
    EXTERNAL_IP=$(kubectl get svc ingress-nginx-controller -n $NAMESPACE -o jsonpath='{.status.loadBalancer.ingress[0].hostname}' 2>/dev/null || echo "")
    if [ ! -z "$EXTERNAL_IP" ] && [ "$EXTERNAL_IP" != "null" ]; then
        echo "✅ LoadBalancer listo: $EXTERNAL_IP"
        break
    fi
    echo "⏳ Esperando LoadBalancer... ($counter/$timeout)"
    sleep 10
    counter=$((counter + 10))
done

if [ $counter -ge $timeout ]; then
    echo "⚠️ Timeout esperando LoadBalancer. Verifica manualmente:"
    echo "kubectl get svc ingress-nginx-controller -n $NAMESPACE"
fi

echo "✅ NGINX Ingress Controller instalado correctamente"
echo ""
echo "🔍 Información del servicio:"
kubectl get svc ingress-nginx-controller -n $NAMESPACE
echo ""
echo "📋 Para verificar el estado:"
echo "kubectl get pods -n $NAMESPACE"
echo "kubectl get ingressclass"

# Limpiar archivo temporal
rm -f nginx-values.yaml
