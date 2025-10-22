#!/bin/bash

set -e

echo "🎯 Iniciando instalación automatizada de controladores de ingress..."
echo "=================================================="

# Función para confirmar acciones
confirm() {
    read -p "$1 (y/N): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        return 0
    else
        return 1
    fi
}

# Función para verificar comandos
check_command() {
    if ! command -v $1 >/dev/null 2>&1; then
        echo "❌ $1 no está instalado o no está en el PATH"
        exit 1
    fi
}

# Verificar prerrequisitos
echo "🔍 Verificando prerrequisitos..."
check_command kubectl
check_command helm
check_command eksctl
check_command aws
check_command curl

echo "✅ Todas las herramientas requeridas están disponibles"

# Cargar configuración
if [ ! -f "config.env" ]; then
    echo "❌ Archivo config.env no encontrado"
    echo "Por favor, copia config.env.example a config.env y configura tus variables"
    exit 1
fi

source config.env

# Validar variables críticas
if [ -z "$CLUSTER_NAME" ] || [ -z "$AWS_REGION" ] || [ -z "$AWS_ACCOUNT_ID" ]; then
    echo "❌ Variables de configuración faltantes en config.env"
    echo "Requeridas: CLUSTER_NAME, AWS_REGION, AWS_ACCOUNT_ID"
    exit 1
fi

echo "📋 Configuración:"
echo "   Cluster: $CLUSTER_NAME"
echo "   Región: $AWS_REGION"
echo "   Account ID: $AWS_ACCOUNT_ID"
if [ ! -z "$VPC_ID" ]; then
    echo "   VPC ID: $VPC_ID"
fi

# Verificar conectividad al cluster
echo ""
echo "🔗 Verificando conectividad al cluster..."

# Intentar conectar primero
if ! kubectl get nodes >/dev/null 2>&1; then
    echo "⚠️ No se puede conectar al cluster, reconfigurando kubectl..."
    
    # Reconfigurar kubectl automáticamente
    echo "🔧 Configurando kubectl para cluster $CLUSTER_NAME..."
    if aws eks update-kubeconfig --region $AWS_REGION --name $CLUSTER_NAME --profile $AWS_PROFILE; then
        echo "✅ kubectl reconfigurado exitosamente"
        
        # Verificar nuevamente
        if ! kubectl get nodes >/dev/null 2>&1; then
            echo "❌ Aún no se puede conectar al cluster después de reconfigurar"
            echo "Verifica que el cluster '$CLUSTER_NAME' existe en la región '$AWS_REGION'"
            exit 1
        fi
    else
        echo "❌ Error reconfigurando kubectl"
        echo "Verifica que el cluster '$CLUSTER_NAME' existe y tienes permisos"
        exit 1
    fi
else
    echo "✅ Conectividad al cluster verificada"
fi

# Obtener contexto del cluster
echo ""
echo "📋 CONTEXTO DEL CLUSTER:"
echo "----------------------------------------"
CURRENT_CONTEXT=$(kubectl config current-context)
echo "   Contexto actual: $CURRENT_CONTEXT"

NODES=$(kubectl get nodes --no-headers | wc -l)
echo "   Nodos disponibles: $NODES"

echo "   Información de nodos:"
kubectl get nodes -o custom-columns="NAME:.metadata.name,STATUS:.status.conditions[?(@.type=='Ready')].status,ROLES:.metadata.labels.kubernetes\.io/role,VERSION:.status.nodeInfo.kubeletVersion,INSTANCE-TYPE:.metadata.labels.node\.kubernetes\.io/instance-type" --no-headers | while read line; do
    echo "     $line"
done

echo "   Namespaces existentes:"
kubectl get ns --no-headers | awk '{print "     " $1}' | head -10

# Verificar si ya existen controladores
echo ""
echo "🔍 Verificando controladores existentes..."
if kubectl get deployment aws-load-balancer-controller -n kube-system >/dev/null 2>&1; then
    echo "   ⚠️ AWS Load Balancer Controller ya existe"
    if ! confirm "¿Continuar con la instalación (sobrescribirá)?"; then
        exit 0
    fi
else
    echo "   ✅ AWS Load Balancer Controller no encontrado"
fi

if kubectl get deployment ingress-nginx-controller -n ${NGINX_NAMESPACE:-ingress-nginx} >/dev/null 2>&1; then
    echo "   ⚠️ NGINX Ingress Controller ya existe en namespace ${NGINX_NAMESPACE:-ingress-nginx}"
    if ! confirm "¿Continuar con la instalación (sobrescribirá)?"; then
        exit 0
    fi
else
    echo "   ✅ NGINX Ingress Controller no encontrado"
fi

echo "----------------------------------------"

# Verificar permisos AWS
echo ""
echo "🔐 Verificando permisos AWS..."
if ! aws sts get-caller-identity >/dev/null 2>&1; then
    echo "❌ No se puede verificar identidad AWS"
    echo "Verifica tu configuración de AWS CLI"
    exit 1
fi

CALLER_IDENTITY=$(aws sts get-caller-identity --query 'Arn' --output text)
echo "✅ Autenticado como: $CALLER_IDENTITY"

# Hacer scripts ejecutables
chmod +x install-aws-lb-controller.sh
chmod +x install-nginx-ingress.sh

echo ""
echo "=================================================="
echo "🚀 Iniciando instalación de controladores..."
echo "=================================================="

# Instalar AWS Load Balancer Controller
echo ""
echo "1️⃣ INSTALANDO AWS LOAD BALANCER CONTROLLER"
echo "----------------------------------------"
if ./install-aws-lb-controller.sh; then
    echo "✅ AWS Load Balancer Controller instalado exitosamente"
else
    echo "❌ Error instalando AWS Load Balancer Controller"
    exit 1
fi

echo ""
echo "⏳ Verificando estado del AWS Load Balancer Controller..."
sleep 10
kubectl get deployment aws-load-balancer-controller -n kube-system

# Instalar NGINX Ingress Controller
echo ""
echo "2️⃣ INSTALANDO NGINX INGRESS CONTROLLER"
echo "------------------------------------"
if ./install-nginx-ingress.sh; then
    echo "✅ NGINX Ingress Controller instalado exitosamente"
else
    echo "❌ Error instalando NGINX Ingress Controller"
    exit 1
fi

echo ""
echo "⏳ Verificando estado del NGINX Ingress Controller..."
sleep 10
kubectl get deployment ingress-nginx-controller -n ${NGINX_NAMESPACE:-ingress-nginx}

echo ""
echo "=================================================="
echo "🎉 ¡INSTALACIÓN COMPLETADA EXITOSAMENTE!"
echo "=================================================="

echo ""
echo "📋 RESUMEN DE INSTALACIÓN:"
echo "✅ AWS Load Balancer Controller: Instalado en namespace kube-system"
echo "✅ NGINX Ingress Controller: Instalado en namespace ${NGINX_NAMESPACE:-ingress-nginx}"

echo ""
echo "🔍 COMANDOS DE VERIFICACIÓN:"
echo "# Verificar AWS Load Balancer Controller:"
echo "kubectl get pods -n kube-system -l app.kubernetes.io/name=aws-load-balancer-controller"
echo ""
echo "# Verificar NGINX Ingress Controller:"
echo "kubectl get pods -n ${NGINX_NAMESPACE:-ingress-nginx}"
echo ""
echo "# Ver servicios LoadBalancer:"
echo "kubectl get svc -n ${NGINX_NAMESPACE:-ingress-nginx}"
echo ""
echo "# Ver IngressClasses disponibles:"
echo "kubectl get ingressclass"

echo ""
echo "📖 PRÓXIMOS PASOS:"
echo "1. Ejecuta './verify-installation.sh' para verificar la instalación"
echo "2. Aplica 'test-app.yaml' para probar los controladores"
echo "3. Consulta el manual para configuraciones avanzadas"

echo ""
echo "⚠️  NOTAS IMPORTANTES:"
echo "- Los LoadBalancers de AWS pueden tardar varios minutos en estar disponibles"
echo "- Verifica que tu VPC tenga subnets públicas correctamente configuradas"
echo "- Mantén actualizadas las versiones de los controladores"
