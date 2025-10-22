# Manual de Instalación Automatizado
## AWS Load Balancer Controller y NGINX Ingress Controller

### Tabla de Contenidos
1. [Prerrequisitos](#prerrequisitos)
2. [Variables de Configuración](#variables-de-configuración)
3. [AWS Load Balancer Controller](#aws-load-balancer-controller)
4. [NGINX Ingress Controller](#nginx-ingress-controller)
5. [Scripts de Automatización](#scripts-de-automatización)
6. [Verificación](#verificación)
7. [Troubleshooting](#troubleshooting)

---

## Prerrequisitos

### Herramientas Requeridas
- `kubectl` configurado para tu cluster EKS
- `helm` v3.x instalado
- `eksctl` instalado
- `aws cli` configurado con permisos adecuados
- Cluster EKS funcionando

### Verificación de Prerrequisitos
```bash
# Verificar herramientas
kubectl version --client
helm version
eksctl version
aws --version

# Verificar conexión al cluster
kubectl get nodes
```

---

## Variables de Configuración

Crea un archivo de configuración con tus variables:

```bash
# config.env
export CLUSTER_NAME="mi-cluster-eks"
export AWS_REGION="us-west-2"
export AWS_ACCOUNT_ID="123456789012"
export VPC_ID="vpc-xxxxxxxxx"
```

---

## AWS Load Balancer Controller

### 1. Configuración IAM

#### Script: `install-aws-lb-controller.sh`
```bash
#!/bin/bash

# Cargar variables
source config.env

echo "🚀 Instalando AWS Load Balancer Controller..."

# 1. Descargar política IAM
echo "📥 Descargando política IAM..."
curl -O https://raw.githubusercontent.com/kubernetes-sigs/aws-load-balancer-controller/v2.14.0/docs/install/iam_policy.json

# 2. Crear política IAM
echo "🔐 Creando política IAM..."
aws iam create-policy \
    --policy-name AWSLoadBalancerControllerIAMPolicy \
    --policy-document file://iam_policy.json \
    --region $AWS_REGION || echo "Política ya existe"

# 3. Crear service account con IAM role
echo "👤 Creando service account..."
eksctl create iamserviceaccount \
    --cluster=$CLUSTER_NAME \
    --namespace=kube-system \
    --name=aws-load-balancer-controller \
    --attach-policy-arn=arn:aws:iam::$AWS_ACCOUNT_ID:policy/AWSLoadBalancerControllerIAMPolicy \
    --override-existing-serviceaccounts \
    --region $AWS_REGION \
    --approve

# 4. Agregar repositorio Helm
echo "📦 Agregando repositorio Helm..."
helm repo add eks https://aws.github.io/eks-charts
helm repo update eks

# 5. Instalar AWS Load Balancer Controller
echo "⚙️ Instalando controlador..."
helm install aws-load-balancer-controller eks/aws-load-balancer-controller \
    -n kube-system \
    --set clusterName=$CLUSTER_NAME \
    --set serviceAccount.create=false \
    --set serviceAccount.name=aws-load-balancer-controller \
    --set region=$AWS_REGION \
    --set vpcId=$VPC_ID \
    --version 1.13.0

echo "✅ AWS Load Balancer Controller instalado correctamente"
```

### 2. Verificación AWS LB Controller
```bash
# Verificar deployment
kubectl get deployment -n kube-system aws-load-balancer-controller

# Verificar logs
kubectl logs -n kube-system deployment/aws-load-balancer-controller
```

---

## NGINX Ingress Controller

### Script: `install-nginx-ingress.sh`
```bash
#!/bin/bash

# Cargar variables
source config.env

echo "🚀 Instalando NGINX Ingress Controller..."

# 1. Agregar repositorio Helm de NGINX
echo "📦 Agregando repositorio Helm de NGINX..."
helm repo add ingress-nginx https://kubernetes.github.io/ingress-nginx
helm repo update

# 2. Crear namespace
echo "📁 Creando namespace..."
kubectl create namespace ingress-nginx --dry-run=client -o yaml | kubectl apply -f -

# 3. Instalar NGINX Ingress Controller
echo "⚙️ Instalando NGINX Ingress Controller..."
helm install ingress-nginx ingress-nginx/ingress-nginx \
    --namespace ingress-nginx \
    --set controller.service.type=LoadBalancer \
    --set controller.service.annotations."service\.beta\.kubernetes\.io/aws-load-balancer-type"="nlb" \
    --set controller.service.annotations."service\.beta\.kubernetes\.io/aws-load-balancer-cross-zone-load-balancing-enabled"="true" \
    --set controller.metrics.enabled=true \
    --set controller.podSecurityContext.fsGroup=2000 \
    --set controller.podSecurityContext.runAsNonRoot=true \
    --set controller.podSecurityContext.runAsUser=1000

echo "✅ NGINX Ingress Controller instalado correctamente"
```

### Configuración Avanzada NGINX
```bash
# Para configuraciones específicas, crear values.yaml
cat > nginx-values.yaml << EOF
controller:
  replicaCount: 2
  
  service:
    type: LoadBalancer
    annotations:
      service.beta.kubernetes.io/aws-load-balancer-type: "nlb"
      service.beta.kubernetes.io/aws-load-balancer-cross-zone-load-balancing-enabled: "true"
      service.beta.kubernetes.io/aws-load-balancer-backend-protocol: "tcp"
  
  resources:
    requests:
      cpu: 100m
      memory: 90Mi
    limits:
      cpu: 200m
      memory: 256Mi
  
  autoscaling:
    enabled: true
    minReplicas: 2
    maxReplicas: 10
    targetCPUUtilizationPercentage: 80
  
  metrics:
    enabled: true
    serviceMonitor:
      enabled: true
EOF

# Instalar con configuración personalizada
helm install ingress-nginx ingress-nginx/ingress-nginx \
    --namespace ingress-nginx \
    --values nginx-values.yaml
```

---

## Scripts de Automatización

### Script Principal: `install-all-controllers.sh`
```bash
#!/bin/bash

set -e

echo "🎯 Iniciando instalación de controladores de ingress..."

# Verificar prerrequisitos
echo "🔍 Verificando prerrequisitos..."
command -v kubectl >/dev/null 2>&1 || { echo "kubectl no encontrado"; exit 1; }
command -v helm >/dev/null 2>&1 || { echo "helm no encontrado"; exit 1; }
command -v eksctl >/dev/null 2>&1 || { echo "eksctl no encontrado"; exit 1; }
command -v aws >/dev/null 2>&1 || { echo "aws cli no encontrado"; exit 1; }

# Cargar configuración
if [ ! -f "config.env" ]; then
    echo "❌ Archivo config.env no encontrado"
    exit 1
fi
source config.env

# Validar variables
if [ -z "$CLUSTER_NAME" ] || [ -z "$AWS_REGION" ] || [ -z "$AWS_ACCOUNT_ID" ]; then
    echo "❌ Variables de configuración faltantes"
    exit 1
fi

# Verificar conectividad al cluster
echo "🔗 Verificando conectividad al cluster..."
kubectl get nodes > /dev/null || { echo "❌ No se puede conectar al cluster"; exit 1; }

# Instalar AWS Load Balancer Controller
echo "1️⃣ Instalando AWS Load Balancer Controller..."
./install-aws-lb-controller.sh

# Esperar a que esté listo
echo "⏳ Esperando a que AWS LB Controller esté listo..."
kubectl wait --for=condition=available --timeout=300s deployment/aws-load-balancer-controller -n kube-system

# Instalar NGINX Ingress Controller
echo "2️⃣ Instalando NGINX Ingress Controller..."
./install-nginx-ingress.sh

# Esperar a que esté listo
echo "⏳ Esperando a que NGINX Ingress esté listo..."
kubectl wait --for=condition=available --timeout=300s deployment/ingress-nginx-controller -n ingress-nginx

echo "🎉 ¡Instalación completada exitosamente!"
echo ""
echo "📋 Resumen de instalación:"
echo "✅ AWS Load Balancer Controller: Instalado"
echo "✅ NGINX Ingress Controller: Instalado"
echo ""
echo "🔍 Para verificar el estado:"
echo "kubectl get pods -n kube-system | grep aws-load-balancer"
echo "kubectl get pods -n ingress-nginx"
```

### Script de Desinstalación: `uninstall-controllers.sh`
```bash
#!/bin/bash

echo "🗑️ Desinstalando controladores..."

# Desinstalar NGINX Ingress
helm uninstall ingress-nginx -n ingress-nginx || true
kubectl delete namespace ingress-nginx || true

# Desinstalar AWS Load Balancer Controller
helm uninstall aws-load-balancer-controller -n kube-system || true

# Limpiar service account
eksctl delete iamserviceaccount \
    --cluster=$CLUSTER_NAME \
    --namespace=kube-system \
    --name=aws-load-balancer-controller \
    --region $AWS_REGION || true

echo "✅ Desinstalación completada"
```

---

## Verificación

### Script de Verificación: `verify-installation.sh`
```bash
#!/bin/bash

echo "🔍 Verificando instalación de controladores..."

# Verificar AWS Load Balancer Controller
echo "1️⃣ AWS Load Balancer Controller:"
kubectl get deployment -n kube-system aws-load-balancer-controller
kubectl get pods -n kube-system -l app.kubernetes.io/name=aws-load-balancer-controller

# Verificar NGINX Ingress Controller
echo ""
echo "2️⃣ NGINX Ingress Controller:"
kubectl get deployment -n ingress-nginx ingress-nginx-controller
kubectl get pods -n ingress-nginx
kubectl get svc -n ingress-nginx

# Obtener Load Balancer externo de NGINX
echo ""
echo "🌐 Load Balancer externo de NGINX:"
kubectl get svc ingress-nginx-controller -n ingress-nginx -o jsonpath='{.status.loadBalancer.ingress[0].hostname}'
echo ""

# Verificar IngressClass
echo ""
echo "📝 IngressClasses disponibles:"
kubectl get ingressclass

echo ""
echo "✅ Verificación completada"
```

### Prueba de Funcionamiento
```bash
# Crear aplicación de prueba
cat > test-app.yaml << EOF
apiVersion: apps/v1
kind: Deployment
metadata:
  name: test-app
spec:
  replicas: 2
  selector:
    matchLabels:
      app: test-app
  template:
    metadata:
      labels:
        app: test-app
    spec:
      containers:
      - name: nginx
        image: nginx:latest
        ports:
        - containerPort: 80
---
apiVersion: v1
kind: Service
metadata:
  name: test-app-service
spec:
  selector:
    app: test-app
  ports:
  - port: 80
    targetPort: 80
---
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: test-app-ingress-nginx
  annotations:
    kubernetes.io/ingress.class: nginx
spec:
  rules:
  - host: test-nginx.example.com
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: test-app-service
            port:
              number: 80
---
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: test-app-ingress-alb
  annotations:
    kubernetes.io/ingress.class: alb
    alb.ingress.kubernetes.io/scheme: internet-facing
    alb.ingress.kubernetes.io/target-type: ip
spec:
  rules:
  - host: test-alb.example.com
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: test-app-service
            port:
              number: 80
EOF

kubectl apply -f test-app.yaml
```

---

## Troubleshooting

### Problemas Comunes

#### 1. AWS Load Balancer Controller no inicia
```bash
# Verificar logs
kubectl logs -n kube-system deployment/aws-load-balancer-controller

# Verificar service account
kubectl describe sa aws-load-balancer-controller -n kube-system

# Verificar IAM role
aws iam get-role --role-name AmazonEKSLoadBalancerControllerRole
```

#### 2. NGINX Ingress no obtiene IP externa
```bash
# Verificar service
kubectl describe svc ingress-nginx-controller -n ingress-nginx

# Verificar eventos
kubectl get events -n ingress-nginx --sort-by='.lastTimestamp'

# Verificar security groups y subnets
aws ec2 describe-security-groups --filters "Name=group-name,Values=*$CLUSTER_NAME*"
```

#### 3. Permisos IAM insuficientes
```bash
# Verificar política actual
aws iam get-policy-version \
    --policy-arn arn:aws:iam::$AWS_ACCOUNT_ID:policy/AWSLoadBalancerControllerIAMPolicy \
    --version-id v1
```

### Comandos de Diagnóstico
```bash
# Estado general del cluster
kubectl get nodes
kubectl get pods --all-namespaces

# Logs de controladores
kubectl logs -n kube-system -l app.kubernetes.io/name=aws-load-balancer-controller
kubectl logs -n ingress-nginx -l app.kubernetes.io/name=ingress-nginx

# Recursos de red
kubectl get svc --all-namespaces
kubectl get ingress --all-namespaces
kubectl get ingressclass
```

---

## Uso de los Scripts

1. **Preparación:**
   ```bash
   chmod +x *.sh
   cp config.env.example config.env
   # Editar config.env con tus valores
   ```

2. **Instalación:**
   ```bash
   ./install-all-controllers.sh
   ```

3. **Verificación:**
   ```bash
   ./verify-installation.sh
   ```

4. **Prueba:**
   ```bash
   kubectl apply -f test-app.yaml
   ```

5. **Limpieza (si es necesario):**
   ```bash
   ./uninstall-controllers.sh
   ```

---

**Notas Importantes:**
- Asegúrate de tener los permisos IAM adecuados
- Verifica que tu VPC tenga subnets públicas y privadas correctamente configuradas
- Los Load Balancers de AWS pueden tardar varios minutos en estar disponibles
- Mantén actualizadas las versiones de los controladores para seguridad
