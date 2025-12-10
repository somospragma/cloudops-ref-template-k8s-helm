#!/bin/bash

# =====================================================
# ALB MASTER DEPLOYMENT SCRIPT
# =====================================================
# Script para desplegar el ALB Master con configuración por ambiente
# Uso: ./deployment.sh <ambiente>
# Ejemplo: ./deployment.sh dev

set -e

# Colores para output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Función para logging
log() {
    echo -e "${BLUE}[$(date +'%Y-%m-%d %H:%M:%S')]${NC} $1"
}

error() {
    echo -e "${RED}[ERROR]${NC} $1" >&2
    exit 1
}

warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

# Validar argumentos
if [ $# -eq 0 ]; then
    error "Uso: $0 <ambiente>"
    error "Ambientes disponibles: dev, staging, prod"
fi

ENVIRONMENT=$1
ENV_FILE=".env.${ENVIRONMENT}"

# Validar que existe el archivo de ambiente
if [ ! -f "$ENV_FILE" ]; then
    error "Archivo de ambiente no encontrado: $ENV_FILE"
fi

log "Iniciando despliegue del ALB Master para ambiente: ${ENVIRONMENT}"

# Cargar variables de ambiente
log "Cargando configuración desde: $ENV_FILE"
source "$ENV_FILE"

# Validar variables críticas
if [ -z "$ALB_MASTER_ENABLED" ]; then
    error "Variable ALB_MASTER_ENABLED no definida en $ENV_FILE"
fi

if [ "$ALB_MASTER_ENABLED" != "true" ]; then
    warning "ALB Master está deshabilitado para ambiente $ENVIRONMENT"
    warning "Para habilitarlo, cambiar ALB_MASTER_ENABLED=true en $ENV_FILE"
    exit 0
fi

# Crear namespace si no existe
log "Verificando namespace: $NAMESPACE"
kubectl get namespace "$NAMESPACE" >/dev/null 2>&1 || {
    log "Creando namespace: $NAMESPACE"
    kubectl create namespace "$NAMESPACE"
}

# Preparar valores para Helm
HELM_VALUES_FILE="values-override-${ENVIRONMENT}.yaml"

log "Generando archivo de valores override: $HELM_VALUES_FILE"

cat > "$HELM_VALUES_FILE" << EOF
# Valores generados automáticamente para ambiente: ${ENVIRONMENT}
# Generado el: $(date)

environment: ${ENVIRONMENT}
namespace: ${NAMESPACE}

albMaster:
  enabled: ${ALB_MASTER_ENABLED}
  groupName: "${ALB_GROUP_NAME}"
  
  ssl:
    enabled: ${SSL_ENABLED}
    redirect: "${SSL_REDIRECT}"
    certificateArn: "${SSL_CERTIFICATE_ARN}"
    policy: "${SSL_POLICY}"
  
  mtls:
    enabled: ${MTLS_ENABLED}
    mutualAuthentication: ${MTLS_MUTUAL_AUTHENTICATION}
  
  waf:
    enabled: ${WAF_ENABLED}
    aclArn: "${WAF_ACL_ARN}"
  
  annotations:
    awsLoadBalancerName: "${ALB_LOAD_BALANCER_NAME}"
    awsListenPorts: '${ALB_LISTEN_PORTS}'
    awsHealthcheckPath: "${ALB_HEALTHCHECK_PATH}"
    awsScheme: "${ALB_SCHEME}"
    awsSubnets: "${ALB_SUBNETS}"
    awsSecurityGroups: "${ALB_SECURITY_GROUPS}"
  
  defaultBackend:
    enabled: ${DEFAULT_BACKEND_ENABLED}
    replicaCount: ${DEFAULT_BACKEND_REPLICAS}
EOF

# Desplegar con Helm
RELEASE_NAME="alb-master-${ENVIRONMENT}"

log "Desplegando ALB Master con Helm..."
log "Release: $RELEASE_NAME"
log "Namespace: $NAMESPACE"

helm upgrade --install "$RELEASE_NAME" . \
    --namespace "$NAMESPACE" \
    --values values.yaml \
    --values "$HELM_VALUES_FILE" \
    --wait \
    --timeout 300s

if [ $? -eq 0 ]; then
    success "ALB Master desplegado exitosamente"
    
    # Mostrar información del despliegue
    log "Información del despliegue:"
    echo "  - Release: $RELEASE_NAME"
    echo "  - Namespace: $NAMESPACE"
    echo "  - Ambiente: $ENVIRONMENT"
    echo "  - Grupo ALB: $ALB_GROUP_NAME"
    
    # Mostrar recursos creados
    log "Recursos creados:"
    kubectl get ingress,deployment,service -n "$NAMESPACE" -l "app.kubernetes.io/instance=$RELEASE_NAME"
    
else
    error "Error durante el despliegue del ALB Master"
fi

# Limpiar archivo temporal
rm -f "$HELM_VALUES_FILE"

log "Despliegue completado"