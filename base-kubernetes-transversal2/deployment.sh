#!/bin/bash

# =====================================================
# EKS CONTROLLERS DEPLOYMENT SCRIPT
# =====================================================
# Script para desplegar AWS Load Balancer Controller y Cluster Autoscaler
# usando Helm con configuración basada en variables de ambiente
# 
# Uso: ./deployment.sh <ambiente>
# Ejemplo: ./deployment.sh dev

set -euo pipefail

# =====================================================
# CONFIGURACIÓN GLOBAL
# =====================================================
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ENVIRONMENT="${1:-}"
ENV_FILE=""
RELEASE_NAME="eks-controllers"
NAMESPACE="kube-system"

# =====================================================
# FUNCIONES DE UTILIDAD
# =====================================================
print_info() {
    echo -e "\033[0;34m[INFO]\033[0m $1"
}

print_success() {
    echo -e "\033[0;32m[SUCCESS]\033[0m $1"
}

print_error() {
    echo -e "\033[0;31m[ERROR]\033[0m $1"
}

print_header() {
    echo -e "\n\033[0;36m========================================\033[0m"
    echo -e "\033[0;36m$1\033[0m"
    echo -e "\033[0;36m========================================\033[0m"
}

show_usage() {
    echo "Uso: $0 <nombre-cluster>"
    echo ""
    echo "El script buscará el archivo .env.<nombre-cluster>"
    echo ""
    echo "Ejemplos:"
    echo "  $0 dev"
    echo "  $0 prod"
    echo "  $0 segundo"
    echo "  $0 mi-cluster-01"
}

validate_environment() {
    ENV_FILE="${SCRIPT_DIR}/.env.${ENVIRONMENT}"
    
    if [[ ! -f "$ENV_FILE" ]]; then
        print_error "Archivo de ambiente no encontrado: $ENV_FILE"
        print_info "Archivos .env disponibles:"
        ls -1 "${SCRIPT_DIR}"/.env.* 2>/dev/null | sed 's|.*/\.env\.||' | sed 's/^/  - /' || echo "  Ninguno encontrado"
        exit 1
    fi
}

load_environment() {
    print_info "Cargando variables de ambiente desde: $ENV_FILE"
    
    # Cargar variables del archivo .env
    set -a
    source "$ENV_FILE"
    set +a
    
    # =====================================================
    # VALORES POR DEFECTO PARA NODECLASS
    # =====================================================
    NODECLASS_ENABLED=${NODECLASS_ENABLED:-false}
    NODECLASS_NAME_OVERRIDE=${NODECLASS_NAME_OVERRIDE:-""}
    NODECLASS_ROLE=${NODECLASS_ROLE:-""}
    NODECLASS_SUBNET_IDS=${NODECLASS_SUBNET_IDS:-""}
    NODECLASS_SG_IDS=${NODECLASS_SG_IDS:-""}
    NODECLASS_EPHEMERAL_SIZE=${NODECLASS_EPHEMERAL_SIZE:-"80Gi"}
    NODECLASS_EPHEMERAL_IOPS=${NODECLASS_EPHEMERAL_IOPS:-3000}
    NODECLASS_EPHEMERAL_THROUGHPUT=${NODECLASS_EPHEMERAL_THROUGHPUT:-125}
    NODECLASS_KMS_KEY_ID=${NODECLASS_KMS_KEY_ID:-""}
    NODECLASS_TAGS=${NODECLASS_TAGS:-""}
    
    # =====================================================
    # VALORES POR DEFECTO PARA NODEPOOL
    # =====================================================
    NODEPOOL_ENABLED=${NODEPOOL_ENABLED:-false}
    NODEPOOL_NAME_OVERRIDE=${NODEPOOL_NAME_OVERRIDE:-""}
    NODEPOOL_NODECLASS_REF=${NODEPOOL_NODECLASS_REF:-""}
    NODEPOOL_INSTANCE_CATEGORIES=${NODEPOOL_INSTANCE_CATEGORIES:-"c,m,r"}
    NODEPOOL_CPU_LIMIT=${NODEPOOL_CPU_LIMIT:-"1000"}
    NODEPOOL_MEMORY_LIMIT=${NODEPOOL_MEMORY_LIMIT:-"1000Gi"}
    
    print_success "Variables cargadas exitosamente"
    
    # Generar contexto automáticamente basado en CLUSTER_NAME y AWS_REGION
    local expected_context="arn:aws:eks:${AWS_REGION}:${AWS_ACCOUNT_ID}:cluster/${CLUSTER_NAME}"
    
    print_info "Configurando contexto para cluster: $CLUSTER_NAME"
    
    # Verificar si el contexto existe
    if ! kubectl config get-contexts -o name | grep -q "^${expected_context}$"; then
        print_info "Contexto no encontrado. Generando contexto para cluster: $CLUSTER_NAME"
        aws eks update-kubeconfig --region "$AWS_REGION" --name "$CLUSTER_NAME"
        print_success "Contexto generado exitosamente"
    fi
    
    print_info "Cambiando contexto de kubectl a: $expected_context"
    kubectl config use-context "$expected_context"
    print_success "Contexto cambiado exitosamente"
}

generate_values_file() {
    local values_file="${SCRIPT_DIR}/values-${ENVIRONMENT}.yaml"
    
    print_info "Generando archivo de valores: $values_file"
    
    cat > "$values_file" << EOF
# =====================================================
# VALORES PARA EKS ADDONS - AMBIENTE: ${ENVIRONMENT}
# =====================================================
# No editar manualmente - se sobrescribe en cada deployment

global:
  clusterName: "${CLUSTER_NAME}"
  awsRegion: "${AWS_REGION}"
  awsAccountId: "${AWS_ACCOUNT_ID}"

# =====================================================


# =====================================================
# KARPENTER - NODECLASS CONFIGURATION
# =====================================================
nodeclass:
  enabled: ${NODECLASS_ENABLED:-false}
  nameOverride: "${NODECLASS_NAME_OVERRIDE:-}"
  role: "${NODECLASS_ROLE:-}"
  
  subnetSelectorTerms:
$(if [ -n "${NODECLASS_SUBNET_IDS:-}" ]; then
    IFS=',' read -ra SUBNET_IDS <<< "${NODECLASS_SUBNET_IDS}"
    for subnet_id in "${SUBNET_IDS[@]}"; do
        echo "  - id: \"${subnet_id}\""
    done
fi)
  
  securityGroupSelectorTerms:
$(if [ -n "${NODECLASS_SG_IDS:-}" ]; then
    IFS=',' read -ra SG_IDS <<< "${NODECLASS_SG_IDS}"
    for sg_id in "${SG_IDS[@]}"; do
        echo "  - id: \"${sg_id}\""
    done
fi)
  
  ephemeralStorage:
    size: "${NODECLASS_EPHEMERAL_SIZE:-80Gi}"
    iops: ${NODECLASS_EPHEMERAL_IOPS:-3000}
    throughput: ${NODECLASS_EPHEMERAL_THROUGHPUT:-125}
  
  snatPolicy: "${NODECLASS_SNAT_POLICY:-Random}"
  networkPolicy: "${NODECLASS_NETWORK_POLICY:-DefaultAllow}"
  networkPolicyEventLogs: "${NODECLASS_NETWORK_POLICY_LOGS:-Disabled}"
  
  $(if [ -n "${NODECLASS_TAGS:-}" ]; then
    echo "tags:"
    IFS=',' read -ra TAG_PAIRS <<< "${NODECLASS_TAGS}"
    for tag_pair in "${TAG_PAIRS[@]}"; do
        IFS='=' read -ra TAG <<< "${tag_pair}"
        echo "    ${TAG[0]}: \"${TAG[1]}\""
    done
fi)

# =====================================================
# KARPENTER - NODEPOOL CONFIGURATION
# =====================================================
nodepool:
  enabled: ${NODEPOOL_ENABLED:-false}
  nameOverride: "${NODEPOOL_NAME_OVERRIDE:-}"
  
  nodeClassRef:
    name: "${NODEPOOL_NODECLASS_REF:-}"
  
  requirements:
$(if [ -n "${NODEPOOL_INSTANCE_CATEGORIES:-}" ]; then
    echo "  - key: \"eks.amazonaws.com/instance-category\""
    echo "    operator: In"
    echo "    values:"
    IFS=',' read -ra CATEGORIES <<< "${NODEPOOL_INSTANCE_CATEGORIES}"
    for category in "${CATEGORIES[@]}"; do
        echo "    - \"${category}\""
    done
fi)
$(if [ -n "${NODEPOOL_ZONES:-}" ]; then
    echo "  - key: \"topology.kubernetes.io/zone\""
    echo "    operator: In"
    echo "    values:"
    IFS=',' read -ra ZONES <<< "${NODEPOOL_ZONES}"
    for zone in "${ZONES[@]}"; do
        echo "    - \"${zone}\""
    done
fi)
$(if [ -n "${NODEPOOL_ARCHITECTURES:-}" ]; then
    echo "  - key: \"kubernetes.io/arch\""
    echo "    operator: In"
    echo "    values:"
    IFS=',' read -ra ARCHS <<< "${NODEPOOL_ARCHITECTURES}"
    for arch in "${ARCHS[@]}"; do
        echo "    - \"${arch}\""
    done
fi)
$(if [ -n "${NODEPOOL_CAPACITY_TYPES:-}" ]; then
    echo "  - key: \"karpenter.sh/capacity-type\""
    echo "    operator: In"
    echo "    values:"
    IFS=',' read -ra TYPES <<< "${NODEPOOL_CAPACITY_TYPES}"
    for type in "${TYPES[@]}"; do
        echo "    - \"${type}\""
    done
fi)
  
  expireAfter: "${NODEPOOL_EXPIRE_AFTER:-72h}"
  terminationGracePeriod: "${NODEPOOL_TERMINATION_GRACE_PERIOD:-1h}"
  
  disruption:
    consolidationPolicy: "${NODEPOOL_CONSOLIDATION_POLICY:-WhenEmptyOrUnderutilized}"
    consolidateAfter: "${NODEPOOL_CONSOLIDATE_AFTER:-60s}"
  
  limits:
    cpu: "${NODEPOOL_CPU_LIMIT:-1000}"
    memory: "${NODEPOOL_MEMORY_LIMIT:-1000Gi}"
  
  weight: ${NODEPOOL_WEIGHT:-100}

# =====================================================
# AWS LOAD BALANCER CONTROLLER
# =====================================================
aws-load-balancer-controller:
  enabled: ${LB_CONTROLLER_ENABLED}
  fullnameOverride: "${LB_CONTROLLER_NAME_OVERRIDE}"
  clusterName: "${CLUSTER_NAME}"
  region: "${AWS_REGION}"
  vpcId: "${VPC_ID}"
  logLevel: ${LB_CONTROLLER_LOG_LEVEL}
  
  serviceAccount:
    create: true
    name: aws-load-balancer-controller
    annotations:
      eks.amazonaws.com/role-arn: "${LB_CONTROLLER_ROLE_ARN}"
  
  replicaCount: ${LB_CONTROLLER_REPLICAS}
  resources:
    limits:
      cpu: ${LB_CONTROLLER_CPU_LIMIT}
      memory: ${LB_CONTROLLER_MEMORY_LIMIT}
    requests:
      cpu: ${LB_CONTROLLER_CPU_REQUEST}
      memory: ${LB_CONTROLLER_MEMORY_REQUEST}

# =====================================================
# CLUSTER AUTOSCALER
# =====================================================
cluster-autoscaler:
  enabled: ${CLUSTER_AUTOSCALER_ENABLED}
  fullnameOverride: "${CLUSTER_AUTOSCALER_NAME_OVERRIDE}"
  autoDiscovery:
    clusterName: "${CLUSTER_NAME}"
    tags:
      - "k8s.io/cluster-autoscaler/enabled"
      - "k8s.io/cluster-autoscaler/${CLUSTER_NAME}"
  
  awsRegion: "${AWS_REGION}"
  
  rbac:
    serviceAccount:
      create: true
      name: cluster-autoscaler
      annotations:
        eks.amazonaws.com/role-arn: "${CLUSTER_AUTOSCALER_ROLE_ARN}"
  
  replicaCount: ${CLUSTER_AUTOSCALER_REPLICAS}
  resources:
    limits:
      cpu: ${CLUSTER_AUTOSCALER_CPU_LIMIT}
      memory: ${CLUSTER_AUTOSCALER_MEMORY_LIMIT}
    requests:
      cpu: ${CLUSTER_AUTOSCALER_CPU_REQUEST}
      memory: ${CLUSTER_AUTOSCALER_MEMORY_REQUEST}
  
  extraArgs:
    scale-down-enabled: ${CA_SCALE_DOWN_ENABLED}
    scale-down-delay-after-add: ${CA_SCALE_DOWN_DELAY_AFTER_ADD}
    scale-down-unneeded-time: ${CA_SCALE_DOWN_UNNEEDED_TIME}
    scale-down-utilization-threshold: ${CA_SCALE_DOWN_UTILIZATION_THRESHOLD}
    max-node-provision-time: ${CA_MAX_NODE_PROVISION_TIME}
    v: ${CA_LOG_LEVEL}
EOF
    
    print_success "Archivo de valores generado: $values_file"
}

generate_manifests() {
    local values_file="${SCRIPT_DIR}/values-${ENVIRONMENT}.yaml"
    local output_dir="${SCRIPT_DIR}/manifests-${ENVIRONMENT}"
    
    print_header "GENERANDO MANIFIESTOS RENDERIZADOS"
    
    # Crear directorio para manifiestos
    mkdir -p "$output_dir"
    
    print_info "Generando manifiestos en: $output_dir"
    
    # Generar manifiestos completos
    helm template "${RELEASE_NAME}-${ENVIRONMENT}" "${SCRIPT_DIR}" \
        --namespace "$NAMESPACE" \
        --values "$values_file" \
        --output-dir "$output_dir"
    
    print_success "Manifiestos generados en: $output_dir"
}

deploy_helm_chart() {
    local values_file="${SCRIPT_DIR}/values-${ENVIRONMENT}.yaml"
    local release_full_name="${RELEASE_NAME}-${ENVIRONMENT}"
    
    print_header "DESPLEGANDO EKS ADDONS - AMBIENTE: ${ENVIRONMENT}"
    
    print_info "Actualizando dependencias de Helm..."
    helm dependency update "${SCRIPT_DIR}"
    
    # Verificar si el release ya existe
    if helm list -n "$NAMESPACE" | grep -q "$release_full_name"; then
        print_info "Release existente encontrado. Ejecutando upgrade..."
        helm upgrade "$release_full_name" "${SCRIPT_DIR}" \
            --namespace "$NAMESPACE" \
            --values "$values_file" \
            --wait \
            --timeout 10m
    else
        print_info "Instalando nuevo release..."
        helm install "$release_full_name" "${SCRIPT_DIR}" \
            --namespace "$NAMESPACE" \
            --values "$values_file" \
            --wait \
            --timeout 10m \
            --create-namespace
    fi
    
    print_success "Deployment completado exitosamente"
}

verify_deployment() {
    local release_full_name="${RELEASE_NAME}-${ENVIRONMENT}"
    
    print_header "VERIFICANDO DEPLOYMENT"
    
    print_info "Contexto actual: $(kubectl config current-context)"
    print_info "Cluster: $CLUSTER_NAME"
    
    print_info "Status del release:"
    helm status "$release_full_name" -n "$NAMESPACE"
    
    print_info "Verificando recursos..."
    
    # Verificar NodeClass
    if [ "${NODECLASS_ENABLED:-false}" = "true" ]; then
        print_info "NodeClass:"
        if kubectl get nodeclass "${NODECLASS_NAME_OVERRIDE:-}" &>/dev/null; then
            kubectl get nodeclass "${NODECLASS_NAME_OVERRIDE:-}" -o wide
        else
            echo "❌ NodeClass no encontrado"
        fi
    fi
    
    # Verificar NodePool
    if [ "${NODEPOOL_ENABLED:-false}" = "true" ]; then
        print_info "NodePool:"
        if kubectl get nodepool "${NODEPOOL_NAME_OVERRIDE:-}" &>/dev/null; then
            kubectl get nodepool "${NODEPOOL_NAME_OVERRIDE:-}" -o wide
        else
            echo "❌ NodePool no encontrado"
        fi
    fi
    
    print_info "Pods de controladores:"
    
    # Verificar Load Balancer Controller
    if kubectl get pods -n "$NAMESPACE" -l app.kubernetes.io/name=aws-load-balancer-controller &>/dev/null; then
        kubectl get pods -n "$NAMESPACE" -l app.kubernetes.io/name=aws-load-balancer-controller -o wide
    fi
    
    # Verificar Cluster Autoscaler
    if kubectl get pods -n "$NAMESPACE" -l app.kubernetes.io/name=aws-cluster-autoscaler &>/dev/null; then
        kubectl get pods -n "$NAMESPACE" -l app.kubernetes.io/name=aws-cluster-autoscaler -o wide
    fi
    
    print_success "Verificación completada"
}

# =====================================================
# FUNCIÓN PRINCIPAL
# =====================================================
main() {
    # Validar argumentos
    if [[ -z "$ENVIRONMENT" ]]; then
        print_error "Debe especificar un ambiente"
        show_usage
        exit 1
    fi
    
    print_header "EKS CONTROLLERS DEPLOYMENT - AMBIENTE: ${ENVIRONMENT}"
    
    # Ejecutar pasos del deployment
    validate_environment
    load_environment
    generate_values_file
    generate_manifests
    deploy_helm_chart
    verify_deployment
    
    print_success "¡Deployment completado exitosamente para ambiente: ${ENVIRONMENT}!"
}

# Ejecutar función principal
main "$@"
