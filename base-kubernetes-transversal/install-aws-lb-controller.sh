#!/bin/bash

set -e

# Cargar variables
if [ ! -f "config.env" ]; then
    echo "❌ Archivo config.env no encontrado"
    exit 1
fi
source config.env

echo "🚀 Instalando AWS Load Balancer Controller..."

# Validar variables requeridas
if [ -z "$CLUSTER_NAME" ] || [ -z "$AWS_REGION" ] || [ -z "$AWS_ACCOUNT_ID" ]; then
    echo "❌ Variables de configuración faltantes en config.env"
    echo "Requeridas: CLUSTER_NAME, AWS_REGION, AWS_ACCOUNT_ID"
    exit 1
fi

# 1. Descargar política IAM
echo "📥 Descargando política IAM..."
curl -O https://raw.githubusercontent.com/kubernetes-sigs/aws-load-balancer-controller/v2.14.0/docs/install/iam_policy.json

# 2. Crear política IAM específica para este cluster
POLICY_NAME="AWSLoadBalancerControllerIAMPolicy-${CLUSTER_NAME}"
echo "🔐 Creando política IAM específica: $POLICY_NAME..."
aws iam create-policy \
    --policy-name $POLICY_NAME \
    --policy-document file://iam_policy.json \
    --profile $AWS_PROFILE 2>/dev/null || echo "ℹ️ Política IAM ya existe"

# 3. Obtener OIDC provider del cluster específico
echo "🔍 Obteniendo OIDC provider del cluster $CLUSTER_NAME..."
OIDC_URL=$(aws eks describe-cluster --name $CLUSTER_NAME --region $AWS_REGION --query "cluster.identity.oidc.issuer" --output text --profile $AWS_PROFILE)
OIDC_ID=$(echo $OIDC_URL | cut -d '/' -f 5)

if ! aws iam list-open-id-connect-providers --profile $AWS_PROFILE | grep -q $OIDC_ID; then
    echo "🔗 Creando OIDC provider para este cluster..."
    aws iam create-open-id-connect-provider \
        --url $OIDC_URL \
        --thumbprint-list 9e99a48a9960b14926bb7f3b02e22da2b0ab7280 \
        --client-id-list sts.amazonaws.com \
        --profile $AWS_PROFILE
else
    echo "ℹ️ OIDC provider ya existe para este cluster"
fi

# 4. Crear IAM role específico para este cluster
ROLE_NAME="AmazonEKSLoadBalancerControllerRole-${CLUSTER_NAME}"
echo "👤 Creando IAM role específico: $ROLE_NAME..."
OIDC_ARN="arn:aws:iam::$AWS_ACCOUNT_ID:oidc-provider/${OIDC_URL#https://}"

cat > trust-policy.json << EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Federated": "$OIDC_ARN"
      },
      "Action": "sts:AssumeRoleWithWebIdentity",
      "Condition": {
        "StringEquals": {
          "${OIDC_URL#https://}:sub": "system:serviceaccount:kube-system:aws-load-balancer-controller",
          "${OIDC_URL#https://}:aud": "sts.amazonaws.com"
        }
      }
    }
  ]
}
EOF

# Crear role específico
aws iam create-role \
    --role-name $ROLE_NAME \
    --assume-role-policy-document file://trust-policy.json \
    --profile $AWS_PROFILE 2>/dev/null || echo "ℹ️ Role ya existe"

# Adjuntar política específica al role
aws iam attach-role-policy \
    --role-name $ROLE_NAME \
    --policy-arn arn:aws:iam::$AWS_ACCOUNT_ID:policy/$POLICY_NAME \
    --profile $AWS_PROFILE

# 5. Crear service account con el role específico
echo "📝 Creando service account con role específico..."
cat > service-account.yaml << EOF
apiVersion: v1
kind: ServiceAccount
metadata:
  labels:
    app.kubernetes.io/component: controller
    app.kubernetes.io/name: aws-load-balancer-controller
  name: aws-load-balancer-controller
  namespace: kube-system
  annotations:
    eks.amazonaws.com/role-arn: arn:aws:iam::$AWS_ACCOUNT_ID:role/$ROLE_NAME
EOF

kubectl apply -f service-account.yaml

# Limpiar archivos temporales
rm -f trust-policy.json service-account.yaml iam_policy.json

# 5. Agregar repositorio Helm
echo "📦 Agregando repositorio Helm..."
helm repo add eks https://aws.github.io/eks-charts
helm repo update eks

# 6. Preparar parámetros adicionales para casos especiales
HELM_PARAMS=""
if [ ! -z "$VPC_ID" ]; then
    HELM_PARAMS="$HELM_PARAMS --set vpcId=$VPC_ID"
fi
HELM_PARAMS="$HELM_PARAMS --set region=$AWS_REGION"

# 7. Instalar AWS Load Balancer Controller
echo "⚙️ Instalando controlador..."
helm install aws-load-balancer-controller eks/aws-load-balancer-controller \
    -n kube-system \
    --set clusterName=$CLUSTER_NAME \
    --set serviceAccount.create=false \
    --set serviceAccount.name=aws-load-balancer-controller \
    --version ${AWS_LB_CONTROLLER_VERSION:-1.13.0} \
    $HELM_PARAMS

# 8. Esperar a que el deployment esté listo
echo "⏳ Esperando a que el controlador esté listo..."
kubectl wait --for=condition=available --timeout=300s deployment/aws-load-balancer-controller -n kube-system

echo "✅ AWS Load Balancer Controller instalado correctamente"
echo ""
echo "🔍 Verificar instalación:"
echo "kubectl get deployment -n kube-system aws-load-balancer-controller"
echo "kubectl logs -n kube-system deployment/aws-load-balancer-controller"
