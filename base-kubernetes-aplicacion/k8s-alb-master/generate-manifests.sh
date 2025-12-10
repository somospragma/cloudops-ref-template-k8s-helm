#!/bin/bash

# =====================================================
# ALB MASTER MANIFEST GENERATOR
# =====================================================
# Script para generar manifiestos YAML sin aplicarlos
# Uso: ./generate-manifests.sh <ambiente> [output-dir]
# Ejemplo: ./generate-manifests.sh prod ./output

set -e

# Colores para output
BLUE='\033[0;34m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

log() {
    echo -e "${BLUE}[$(date +'%Y-%m-%d %H:%M:%S')]${NC} $1"
}

success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

warning() {
    echo -e "${YELLOW}[INFO]${NC} $1"
}

# Validar argumentos
if [ $# -eq 0 ]; then
    echo "Uso: $0 <ambiente> [output-dir]"
    echo "Ambientes: dev, staging, prod"
    echo "Ejemplo: $0 prod ./manifests-output"
    exit 1
fi

ENVIRONMENT=$1
OUTPUT_DIR=${2:-"./manifests-${ENVIRONMENT}"}
ENV_FILE=".env.${ENVIRONMENT}"

# Validar archivo de ambiente
if [ ! -f "$ENV_FILE" ]; then
    echo "Error: Archivo $ENV_FILE no encontrado"
    exit 1
fi

log "Generando manifiestos para ambiente: ${ENVIRONMENT}"
log "Directorio de salida: ${OUTPUT_DIR}"

# Crear directorio de salida
mkdir -p "$OUTPUT_DIR"

# Cargar variables de ambiente
source "$ENV_FILE"

# Generar archivo de valores override
HELM_VALUES_FILE="${OUTPUT_DIR}/values-override-${ENVIRONMENT}.yaml"

log "Generando valores override: $HELM_VALUES_FILE"

cat > "$HELM_VALUES_FILE" << EOF
# Valores generados para ambiente: ${ENVIRONMENT}
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
    mutualAuthentication: "${MTLS_MUTUAL_AUTHENTICATION}"
  
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

# Generar manifiestos con Helm template
RELEASE_NAME="alb-master-${ENVIRONMENT}"
MANIFEST_FILE="${OUTPUT_DIR}/alb-master-${ENVIRONMENT}.yaml"

log "Generando manifiestos YAML: $MANIFEST_FILE"

helm template "$RELEASE_NAME" . \
    --namespace "$NAMESPACE" \
    --values values.yaml \
    --values "$HELM_VALUES_FILE" \
    > "$MANIFEST_FILE"

# Generar archivo de información
INFO_FILE="${OUTPUT_DIR}/deployment-info.txt"

cat > "$INFO_FILE" << EOF
ALB MASTER - INFORMACIÓN DE DESPLIEGUE
=====================================

Ambiente: ${ENVIRONMENT}
Generado: $(date)
Release: ${RELEASE_NAME}
Namespace: ${NAMESPACE}

CONFIGURACIÓN:
- ALB Habilitado: ${ALB_MASTER_ENABLED}
- Grupo ALB: ${ALB_GROUP_NAME}
- Nombre ALB: ${ALB_LOAD_BALANCER_NAME}
- Esquema: ${ALB_SCHEME}
- SSL Habilitado: ${SSL_ENABLED}
- mTLS Habilitado: ${MTLS_ENABLED}
- WAF Habilitado: ${WAF_ENABLED}

ARCHIVOS GENERADOS:
- values-override-${ENVIRONMENT}.yaml (valores Helm)
- alb-master-${ENVIRONMENT}.yaml (manifiestos K8s)
- deployment-info.txt (esta información)

COMANDOS PARA APLICAR:
kubectl apply -f ${MANIFEST_FILE}

O usar el script de despliegue:
./deployment.sh ${ENVIRONMENT}
EOF

success "Manifiestos generados exitosamente"
warning "Archivos creados en: ${OUTPUT_DIR}/"
warning "Revisar manifiestos antes de aplicar"

# Mostrar resumen de archivos
echo ""
echo "Archivos generados:"
ls -la "$OUTPUT_DIR/"

echo ""
echo "Para aplicar los manifiestos:"
echo "  kubectl apply -f ${MANIFEST_FILE}"
echo ""
echo "Para usar el script de despliegue:"
echo "  ./deployment.sh ${ENVIRONMENT}"