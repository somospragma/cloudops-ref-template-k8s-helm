#!/bin/bash

set -e

# Cargar configuración si existe
if [ -f "config.env" ]; then
    source config.env
fi

NAMESPACE=${NGINX_NAMESPACE:-ingress-nginx}

echo "🗑️ DESINSTALANDO CONTROLADORES DE INGRESS"
echo "=========================================="

# Función para confirmar acción
confirm() {
    read -p "$1 (y/N): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        return 0
    else
        return 1
    fi
}

echo "⚠️ Esta acción eliminará:"
echo "   - AWS Load Balancer Controller"
echo "   - NGINX Ingress Controller"
echo "   - Cluster Autoscaler"
echo "   - Service Accounts asociados"
echo "   - Recursos IAM asociados"
echo ""

if ! confirm "¿Estás seguro de que quieres continuar?"; then
    echo "❌ Operación cancelada"
    exit 0
fi

echo ""
echo "🧹 Iniciando proceso de desinstalación..."

# 1. Desinstalar NGINX Ingress Controller
echo ""
echo "1️⃣ Desinstalando NGINX Ingress Controller..."
if helm list -n $NAMESPACE | grep -q ingress-nginx; then
    helm uninstall ingress-nginx -n $NAMESPACE
    echo "   ✅ NGINX Ingress Controller desinstalado"
else
    echo "   ℹ️ NGINX Ingress Controller no encontrado via Helm"
fi

# Eliminar namespace de NGINX solo si fue creado por nuestro script
echo "   🗂️ Verificando namespace $NAMESPACE..."
if kubectl get namespace $NAMESPACE -o jsonpath='{.metadata.labels.created-by}' 2>/dev/null | grep -q "nginx-install-script"; then
    kubectl delete namespace $NAMESPACE
    echo "   ✅ Namespace $NAMESPACE eliminado (creado por nuestro script)"
else
    echo "   ℹ️ Namespace $NAMESPACE no fue creado por nuestro script, conservado"
fi

# 2. Desinstalar AWS Load Balancer Controller
echo ""
echo "2️⃣ Desinstalando AWS Load Balancer Controller..."
if helm list -n kube-system | grep -q aws-load-balancer-controller; then
    helm uninstall aws-load-balancer-controller -n kube-system
    echo "   ✅ AWS Load Balancer Controller desinstalado"
else
    echo "   ℹ️ AWS Load Balancer Controller no encontrado via Helm"
fi

# 3. Desinstalar Cluster Autoscaler
echo ""
echo "3️⃣ Desinstalando Cluster Autoscaler..."
if kubectl get deployment cluster-autoscaler -n kube-system >/dev/null 2>&1; then
    kubectl delete deployment cluster-autoscaler -n kube-system
    echo "   ✅ Cluster Autoscaler deployment eliminado"
else
    echo "   ℹ️ Cluster Autoscaler deployment no encontrado"
fi

# Eliminar RBAC de Cluster Autoscaler
kubectl delete clusterrole cluster-autoscaler 2>/dev/null || echo "   ℹ️ ClusterRole cluster-autoscaler no encontrado"
kubectl delete clusterrolebinding cluster-autoscaler 2>/dev/null || echo "   ℹ️ ClusterRoleBinding cluster-autoscaler no encontrado"
kubectl delete role cluster-autoscaler -n kube-system 2>/dev/null || echo "   ℹ️ Role cluster-autoscaler no encontrado"
kubectl delete rolebinding cluster-autoscaler -n kube-system 2>/dev/null || echo "   ℹ️ RoleBinding cluster-autoscaler no encontrado"

# Eliminar Service Account de Cluster Autoscaler
if kubectl get sa cluster-autoscaler -n kube-system >/dev/null 2>&1; then
    kubectl delete sa cluster-autoscaler -n kube-system
    echo "   ✅ Service Account cluster-autoscaler eliminado"
else
    echo "   ℹ️ Service Account cluster-autoscaler no encontrado"
fi

# 4. Eliminar Service Account y IAM role de AWS LB Controller
echo ""
echo "4️⃣ Eliminando Service Account y IAM role de AWS LB Controller..."
if kubectl get sa aws-load-balancer-controller -n kube-system >/dev/null 2>&1; then
    kubectl delete sa aws-load-balancer-controller -n kube-system
    echo "   ✅ Service Account eliminado"
else
    echo "   ℹ️ Service Account no encontrado"
fi

# Eliminar IAM role específico del cluster
if [ ! -z "$AWS_ACCOUNT_ID" ] && [ ! -z "$CLUSTER_NAME" ]; then
    ROLE_NAME="EKSLoadBalancerRole"
    POLICY_NAME="EKSLoadBalancerPolicy"
    
    aws iam detach-role-policy \
        --role-name $ROLE_NAME \
        --policy-arn arn:aws:iam::$AWS_ACCOUNT_ID:policy/$POLICY_NAME \
        2>/dev/null || echo "   ℹ️ Política ya desvinculada"
    
    aws iam delete-role \
        --role-name $ROLE_NAME \
        2>/dev/null || echo "   ℹ️ Role no encontrado"
    
    echo "   ✅ IAM role específico eliminado: $ROLE_NAME"
else
    echo "   ⚠️ AWS_ACCOUNT_ID o CLUSTER_NAME no definidos, no se puede eliminar IAM role"
fi

# 5. Limpiar CRDs (opcional)
echo ""
echo "5️⃣ Limpiando Custom Resource Definitions..."
if confirm "¿Eliminar CRDs de AWS Load Balancer Controller? (Esto puede afectar otros clusters)"; then
    kubectl delete crd ingressclassparams.elbv2.k8s.aws 2>/dev/null || echo "   ℹ️ CRD ingressclassparams no encontrado"
    kubectl delete crd targetgroupbindings.elbv2.k8s.aws 2>/dev/null || echo "   ℹ️ CRD targetgroupbindings no encontrado"
    echo "   ✅ CRDs eliminados"
else
    echo "   ℹ️ CRDs conservados"
fi

# 6. Limpiar políticas IAM específicas del cluster
echo ""
echo "6️⃣ Limpiando políticas IAM específicas del cluster..."
if [ ! -z "$AWS_ACCOUNT_ID" ] && [ ! -z "$CLUSTER_NAME" ]; then
    POLICY_NAME="AWSLoadBalancerControllerIAMPolicy-${CLUSTER_NAME}"
    if confirm "¿Eliminar política IAM específica $POLICY_NAME?"; then
        aws iam delete-policy \
            --policy-arn arn:aws:iam::$AWS_ACCOUNT_ID:policy/$POLICY_NAME \
            \
            2>/dev/null || echo "   ⚠️ Error eliminando política IAM o no existe"
        echo "   ✅ Política IAM específica eliminada: $POLICY_NAME"
    else
        echo "   ℹ️ Política IAM específica conservada: $POLICY_NAME"
    fi
else
    echo "   ⚠️ AWS_ACCOUNT_ID o CLUSTER_NAME no definidos, no se puede eliminar política IAM"
fi

# Limpiar IAM role y policy de Cluster Autoscaler
if [ ! -z "$AWS_ACCOUNT_ID" ] && [ ! -z "$CLUSTER_NAME" ]; then
    CA_ROLE_NAME="AmazonEKSClusterAutoscalerRole-${CLUSTER_NAME}"
    CA_POLICY_NAME="AmazonEKSClusterAutoscalerPolicy-${CLUSTER_NAME}"
    
    # Desvincular y eliminar role de Cluster Autoscaler
    aws iam detach-role-policy \
        --role-name $CA_ROLE_NAME \
        --policy-arn arn:aws:iam::$AWS_ACCOUNT_ID:policy/$CA_POLICY_NAME \
        2>/dev/null || echo "   ℹ️ Política de Cluster Autoscaler ya desvinculada"
    
    aws iam delete-role \
        --role-name $CA_ROLE_NAME \
        2>/dev/null || echo "   ℹ️ Role de Cluster Autoscaler no encontrado"
    
    if confirm "¿Eliminar política IAM de Cluster Autoscaler $CA_POLICY_NAME?"; then
        aws iam delete-policy \
            --policy-arn arn:aws:iam::$AWS_ACCOUNT_ID:policy/$CA_POLICY_NAME \
            \
            2>/dev/null || echo "   ⚠️ Error eliminando política de Cluster Autoscaler o no existe"
        echo "   ✅ Política IAM de Cluster Autoscaler eliminada: $CA_POLICY_NAME"
    else
        echo "   ℹ️ Política IAM de Cluster Autoscaler conservada: $CA_POLICY_NAME"
    fi
    
    echo "   ✅ IAM role de Cluster Autoscaler eliminado: $CA_ROLE_NAME"
else
    echo "   ⚠️ AWS_ACCOUNT_ID o CLUSTER_NAME no definidos, no se puede eliminar IAM role de Cluster Autoscaler"
fi

# 8. Eliminar NodeClass y NodePool
echo ""
echo "8️⃣ Eliminando NodeClass y NodePool..."
if [ "$INSTALL_NODECLASS_NODEPOOL" = "true" ] || kubectl get nodeclass 2>/dev/null | grep -q .; then
    # Eliminar NodePool primero (depende de NodeClass)
    if kubectl get nodepool $NODEPOOL_NAME 2>/dev/null; then
        echo "   🗑️ Eliminando NodePool: $NODEPOOL_NAME"
        kubectl delete nodepool $NODEPOOL_NAME
        echo "   ✅ NodePool eliminado: $NODEPOOL_NAME"
    else
        echo "   ℹ️ NodePool no encontrado: $NODEPOOL_NAME"
    fi
    
    # Eliminar NodeClass
    if kubectl get nodeclass $NODECLASS_NAME 2>/dev/null; then
        echo "   🗑️ Eliminando NodeClass: $NODECLASS_NAME"
        kubectl delete nodeclass $NODECLASS_NAME
        echo "   ✅ NodeClass eliminado: $NODECLASS_NAME"
    else
        echo "   ℹ️ NodeClass no encontrado: $NODECLASS_NAME"
    fi
    
    # Eliminar todos los NodeClass y NodePool si existen otros
    echo "   🧹 Limpiando NodeClass y NodePool restantes..."
    kubectl delete nodepool --all 2>/dev/null || echo "   ℹ️ No hay más NodePool para eliminar"
    kubectl delete nodeclass --all 2>/dev/null || echo "   ℹ️ No hay más NodeClass para eliminar"
else
    echo "   ⏭️ NodeClass y NodePool no instalados o no encontrados"
fi

# 9. Limpiar archivos temporales
echo ""
echo "7️⃣ Limpiando archivos temporales..."
rm -f iam_policy.json
rm -f nginx-values.yaml
rm -f crds.yaml
echo "   ✅ Archivos temporales eliminados"

# 8. Verificación final
echo ""
echo "8️⃣ Verificación final..."
echo "   📋 Deployments restantes en kube-system:"
kubectl get deployment -n kube-system | grep -E "(aws-load-balancer|ingress|cluster-autoscaler)" || echo "   ✅ No se encontraron deployments de controladores"

echo ""
echo "   📋 Deployments restantes en $NAMESPACE:"
kubectl get deployment -n $NAMESPACE 2>/dev/null | grep ingress || echo "   ✅ No se encontraron deployments de NGINX"

echo ""
echo "   📋 IngressClasses restantes:"
kubectl get ingressclass 2>/dev/null || echo "   ℹ️ No se encontraron IngressClasses"

echo ""
echo "=========================================="
echo "✅ DESINSTALACIÓN COMPLETADA"
echo "=========================================="

echo ""
echo "📋 RESUMEN:"
echo "✅ AWS Load Balancer Controller: Eliminado"
echo "✅ NGINX Ingress Controller: Eliminado"
echo "✅ Cluster Autoscaler: Eliminado"
echo "✅ NodeClass y NodePool: Eliminados"

echo "✅ Archivos temporales: Eliminados"

echo ""
echo "⚠️ NOTAS:"
echo "- Los LoadBalancers de AWS pueden tardar unos minutos en eliminarse completamente"
echo "- Verifica en la consola de AWS que no queden recursos huérfanos"
echo "- Si conservaste las políticas IAM, puedes reutilizarlas en futuras instalaciones"

echo ""
echo "🔍 COMANDOS DE VERIFICACIÓN:"
echo "# Verificar que no queden pods:"
echo "kubectl get pods --all-namespaces | grep -E '(aws-load-balancer|ingress-nginx)'"
echo ""
echo "# Verificar LoadBalancers en AWS:"
echo "aws elbv2 describe-load-balancers --region $AWS_REGION"
echo ""
echo "# Verificar políticas IAM:"
echo "aws iam list-policies --scope Local | grep LoadBalancer"
