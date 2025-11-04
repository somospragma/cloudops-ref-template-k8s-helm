#!/bin/bash

set -e

# Cargar variables
if [ ! -f "config.env" ]; then
    echo "❌ Archivo config.env no encontrado"
    exit 1
fi
source config.env

# Verificar si se debe instalar Cluster Autoscaler
if [ "$INSTALL_CLUSTER_AUTOSCALER" != "true" ]; then
    echo "⏭️ Cluster Autoscaler deshabilitado (INSTALL_CLUSTER_AUTOSCALER=$INSTALL_CLUSTER_AUTOSCALER)"
    echo "✅ Saltando instalación de Cluster Autoscaler"
    exit 0
fi

echo "🚀 Instalando Cluster Autoscaler..."

# Validar variables requeridas
if [ -z "$CLUSTER_NAME" ] || [ -z "$AWS_REGION" ] || [ -z "$AWS_ACCOUNT_ID" ]; then
    echo "❌ Variables de configuración faltantes en config.env"
    echo "Requeridas: CLUSTER_NAME, AWS_REGION, AWS_ACCOUNT_ID"
    exit 1
fi

# 1. Verificar que existan node groups
echo "🔍 Verificando node groups del cluster..."
NODE_GROUPS=$(aws eks list-nodegroups --cluster-name $CLUSTER_NAME --region $AWS_REGION --query 'nodegroups' --output text)

if [ -z "$NODE_GROUPS" ] || [ "$NODE_GROUPS" = "None" ]; then
    echo "❌ No se encontraron node groups en el cluster $CLUSTER_NAME"
    echo "💡 Cluster Autoscaler requiere node groups con Auto Scaling Groups"
    exit 1
fi

echo "✅ Node groups encontrados: $NODE_GROUPS"

# 2. Verificar y configurar tags en los ASG
echo "📋 Configurando tags en Auto Scaling Groups..."
for nodegroup in $NODE_GROUPS; do
    echo "   Procesando node group: $nodegroup"
    
    # Obtener el ASG asociado al node group
    ASG_NAME=$(aws eks describe-nodegroup \
        --cluster-name $CLUSTER_NAME \
        --nodegroup-name $nodegroup \
        --region $AWS_REGION \
        \
        --query 'nodegroup.resources.autoScalingGroups[0].name' \
        --output text)
    
    if [ ! -z "$ASG_NAME" ] && [ "$ASG_NAME" != "None" ]; then
        echo "   ASG encontrado: $ASG_NAME"
        
        # Agregar tags requeridos para Cluster Autoscaler
        aws autoscaling create-or-update-tags \
            --tags "ResourceId=$ASG_NAME,ResourceType=auto-scaling-group,Key=k8s.io/cluster-autoscaler/$CLUSTER_NAME,Value=owned,PropagateAtLaunch=false" \
            --region $AWS_REGION \
           
        
        aws autoscaling create-or-update-tags \
            --tags "ResourceId=$ASG_NAME,ResourceType=auto-scaling-group,Key=k8s.io/cluster-autoscaler/enabled,Value=true,PropagateAtLaunch=false" \
            --region $AWS_REGION \
           
        
        echo "   ✅ Tags configurados para ASG: $ASG_NAME"
    else
        echo "   ⚠️ No se pudo encontrar ASG para node group: $nodegroup"
    fi
done

# 3. Crear política IAM para Cluster Autoscaler
echo "🔐 Creando política IAM para Cluster Autoscaler..."
POLICY_NAME="AmazonEKSClusterAutoscalerPolicy"

cat > cluster-autoscaler-policy.json << EOF
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
                "ec2:DescribeLaunchTemplateVersions"
            ],
            "Resource": "*"
        }
    ]
}
EOF

aws iam create-policy \
    --policy-name $POLICY_NAME \
    --policy-document file://cluster-autoscaler-policy.json \
    2>/dev/null || echo "ℹ️ Política IAM ya existe"

# 4. Obtener OIDC provider del cluster
echo "🔍 Obteniendo OIDC provider del cluster..."
OIDC_URL=$(aws eks describe-cluster --name $CLUSTER_NAME --region $AWS_REGION --query "cluster.identity.oidc.issuer" --output text)
OIDC_ID=$(echo $OIDC_URL | cut -d '/' -f 5)

# 5. Crear IAM role para Cluster Autoscaler
echo "👤 Creando IAM role para Cluster Autoscaler..."
ROLE_NAME="AmazonEKSClusterAutoscalerRole"
OIDC_ARN="arn:aws:iam::$AWS_ACCOUNT_ID:oidc-provider/${OIDC_URL#https://}"

cat > cluster-autoscaler-trust-policy.json << EOF
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
          "${OIDC_URL#https://}:sub": "system:serviceaccount:kube-system:cluster-autoscaler",
          "${OIDC_URL#https://}:aud": "sts.amazonaws.com"
        }
      }
    }
  ]
}
EOF

aws iam create-role \
    --role-name $ROLE_NAME \
    --assume-role-policy-document file://cluster-autoscaler-trust-policy.json \
    2>/dev/null || echo "ℹ️ Role ya existe"

# Adjuntar política al role
aws iam attach-role-policy \
    --role-name $ROLE_NAME \
    --policy-arn arn:aws:iam::$AWS_ACCOUNT_ID:policy/$POLICY_NAME \
   

# 6. Crear service account
echo "📝 Creando service account..."
cat > cluster-autoscaler-service-account.yaml << EOF
apiVersion: v1
kind: ServiceAccount
metadata:
  labels:
    k8s-addon: cluster-autoscaler.addons.k8s.io
    k8s-app: cluster-autoscaler
  name: cluster-autoscaler
  namespace: kube-system
  annotations:
    eks.amazonaws.com/role-arn: arn:aws:iam::$AWS_ACCOUNT_ID:role/$ROLE_NAME
EOF

kubectl apply -f cluster-autoscaler-service-account.yaml

# 7. Desplegar Cluster Autoscaler
echo "⚙️ Desplegando Cluster Autoscaler..."
cat > cluster-autoscaler-deployment.yaml << EOF
apiVersion: apps/v1
kind: Deployment
metadata:
  name: cluster-autoscaler
  namespace: kube-system
  labels:
    app: cluster-autoscaler
spec:
  replicas: 1
  selector:
    matchLabels:
      app: cluster-autoscaler
  template:
    metadata:
      labels:
        app: cluster-autoscaler
      annotations:
        prometheus.io/scrape: 'true'
        prometheus.io/port: '8085'
    spec:
      priorityClassName: system-cluster-critical
      securityContext:
        runAsNonRoot: true
        runAsUser: 65534
        fsGroup: 65534
      serviceAccountName: cluster-autoscaler
      containers:
      - image: registry.k8s.io/autoscaling/cluster-autoscaler:v${CLUSTER_AUTOSCALER_VERSION}
        name: cluster-autoscaler
        resources:
          limits:
            cpu: 100m
            memory: 600Mi
          requests:
            cpu: 100m
            memory: 600Mi
        command:
        - ./cluster-autoscaler
        - --v=4
        - --stderrthreshold=info
        - --cloud-provider=aws
        - --skip-nodes-with-local-storage=false
        - --expander=least-waste
        - --node-group-auto-discovery=asg:tag=k8s.io/cluster-autoscaler/enabled,k8s.io/cluster-autoscaler/$CLUSTER_NAME
        - --balance-similar-node-groups
        - --scale-down-delay-after-add=${SCALE_DOWN_DELAY_AFTER_ADD:-10m}
        - --scale-down-unneeded-time=${SCALE_DOWN_UNNEEDED_TIME:-10m}
        - --scale-down-utilization-threshold=${SCALE_DOWN_UTILIZATION_THRESHOLD:-0.5}
        - --skip-nodes-with-system-pods=false
        volumeMounts:
        - name: ssl-certs
          mountPath: /etc/ssl/certs/ca-certificates.crt
          readOnly: true
        imagePullPolicy: "Always"
      volumes:
      - name: ssl-certs
        hostPath:
          path: "/etc/ssl/certs/ca-bundle.crt"
      nodeSelector:
        kubernetes.io/os: linux
EOF

kubectl apply -f cluster-autoscaler-deployment.yaml

# 8. Configurar RBAC
echo "🔒 Configurando RBAC..."
cat > cluster-autoscaler-rbac.yaml << EOF
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: cluster-autoscaler
  labels:
    k8s-addon: cluster-autoscaler.addons.k8s.io
    k8s-app: cluster-autoscaler
rules:
- apiGroups: [""]
  resources: ["events", "endpoints"]
  verbs: ["create", "patch"]
- apiGroups: [""]
  resources: ["pods/eviction"]
  verbs: ["create"]
- apiGroups: [""]
  resources: ["pods/status"]
  verbs: ["update"]
- apiGroups: [""]
  resources: ["endpoints"]
  resourceNames: ["cluster-autoscaler"]
  verbs: ["get", "update"]
- apiGroups: [""]
  resources: ["nodes"]
  verbs: ["watch", "list", "get", "update"]
- apiGroups: [""]
  resources: ["namespaces", "pods", "services", "replicationcontrollers", "persistentvolumeclaims", "persistentvolumes"]
  verbs: ["watch", "list", "get"]
- apiGroups: ["extensions"]
  resources: ["replicasets", "daemonsets"]
  verbs: ["watch", "list", "get"]
- apiGroups: ["policy"]
  resources: ["poddisruptionbudgets"]
  verbs: ["watch", "list"]
- apiGroups: ["apps"]
  resources: ["statefulsets", "replicasets", "daemonsets"]
  verbs: ["watch", "list", "get"]
- apiGroups: ["storage.k8s.io"]
  resources: ["storageclasses", "csinodes", "csidrivers", "csistoragecapacities"]
  verbs: ["watch", "list", "get"]
- apiGroups: ["batch", "extensions"]
  resources: ["jobs"]
  verbs: ["get", "list", "watch", "patch"]
- apiGroups: ["coordination.k8s.io"]
  resources: ["leases"]
  verbs: ["create"]
- apiGroups: ["coordination.k8s.io"]
  resourceNames: ["cluster-autoscaler"]
  resources: ["leases"]
  verbs: ["get", "update"]
---
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  name: cluster-autoscaler
  namespace: kube-system
  labels:
    k8s-addon: cluster-autoscaler.addons.k8s.io
    k8s-app: cluster-autoscaler
rules:
- apiGroups: [""]
  resources: ["configmaps"]
  verbs: ["create","list","watch"]
- apiGroups: [""]
  resources: ["configmaps"]
  resourceNames: ["cluster-autoscaler-status", "cluster-autoscaler-priority-expander"]
  verbs: ["delete", "get", "update", "watch"]
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: cluster-autoscaler
  labels:
    k8s-addon: cluster-autoscaler.addons.k8s.io
    k8s-app: cluster-autoscaler
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: cluster-autoscaler
subjects:
- kind: ServiceAccount
  name: cluster-autoscaler
  namespace: kube-system
---
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: cluster-autoscaler
  namespace: kube-system
  labels:
    k8s-addon: cluster-autoscaler.addons.k8s.io
    k8s-app: cluster-autoscaler
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: Role
  name: cluster-autoscaler
subjects:
- kind: ServiceAccount
  name: cluster-autoscaler
  namespace: kube-system
EOF

kubectl apply -f cluster-autoscaler-rbac.yaml

# 9. Esperar a que el deployment esté listo
echo "⏳ Esperando a que Cluster Autoscaler esté listo..."
kubectl wait --for=condition=available --timeout=300s deployment/cluster-autoscaler -n kube-system

# 10. Limpiar archivos temporales
rm -f cluster-autoscaler-policy.json
rm -f cluster-autoscaler-trust-policy.json
rm -f cluster-autoscaler-service-account.yaml
rm -f cluster-autoscaler-deployment.yaml
rm -f cluster-autoscaler-rbac.yaml

echo "✅ Cluster Autoscaler instalado correctamente"
echo ""
echo "🔍 Información del deployment:"
kubectl get deployment cluster-autoscaler -n kube-system
echo ""
echo "📋 Para verificar el estado:"
echo "kubectl logs -n kube-system deployment/cluster-autoscaler"
echo "kubectl get nodes"
echo ""
echo "💡 Para probar el autoscaling:"
echo "kubectl apply -f https://k8s.io/examples/application/php-apache.yaml"
echo "kubectl autoscale deployment php-apache --cpu-percent=50 --min=1 --max=10"