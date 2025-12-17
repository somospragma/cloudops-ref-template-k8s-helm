#!/bin/bash

# =====================================================
# KUBERNETES APPLICATION MANIFEST GENERATOR
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
ENV_FILE="../.env.${ENVIRONMENT}"

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

appName: microservicio-app
namespace: ${NAMESPACE}
environment: ${ENVIRONMENT}

image:
  registry: ${IMAGE_REGISTRY}
  repository: ${IMAGE_REPOSITORY}
  tag: "${IMAGE_TAG}"

replicaCount: ${REPLICA_COUNT}

resources:
  requests:
    memory: "${MEMORY_REQUEST}"
    cpu: "${CPU_REQUEST}"
  limits:
    memory: "${MEMORY_LIMIT}"
    cpu: "${CPU_LIMIT}"

service:
  port: ${SERVICE_PORT}

configMap:
  enabled: ${CONFIGMAP_ENABLED}

ingress:
  enabled: ${INGRESS_ENABLED}
  className: ${INGRESS_CLASS_NAME}
  group:
    enabled: ${INGRESS_GROUP_ENABLED}
  rules:
    - host: "${INGRESS_HOST:-}"
      paths:
        - path: ${INGRESS_PATH}
          pathType: Prefix
          servicePort: ${SERVICE_PORT}
  annotations:
    rewriteTarget: "${INGRESS_REWRITE_TARGET}"
    awsHealthcheckPath: "${INGRESS_HEALTHCHECK_PATH}"
    awsGroupName: "${INGRESS_GROUP_NAME}"
    awsListenPorts: '${INGRESS_LISTEN_PORTS}'
    custom: {}
  tls:
    enabled: ${INGRESS_TLS_ENABLED}
    hosts: 
      - "${INGRESS_TLS_HOSTS}"
    secretName: "${INGRESS_TLS_SECRET_NAME}"
  mtls:
    enabled: ${INGRESS_MTLS_ENABLED}
    secretName: "${INGRESS_MTLS_SECRET_NAME}"
    verifyClient: "${INGRESS_MTLS_VERIFY_CLIENT}"

hpa:
  enabled: ${HPA_ENABLED}
  minReplicas: ${HPA_MIN_REPLICAS}
  maxReplicas: ${HPA_MAX_REPLICAS}
  targetCPUUtilizationPercentage: ${HPA_TARGET_CPU}
  targetMemoryUtilizationPercentage: ${HPA_TARGET_MEMORY}

serviceAccount:
  enabled: ${SERVICEACCOUNT_ENABLED}
  annotations:
    irsaRoleArn: "${SERVICEACCOUNT_IRSA_ROLE_ARN}"
    azureClientId: "${SERVICEACCOUNT_AZURE_CLIENT_ID}"

pdb:
  enabled: ${PDB_ENABLED}
  minAvailable: ${PDB_MIN_AVAILABLE}
  maxUnavailable: "${PDB_MAX_UNAVAILABLE}"
EOF

# Generar manifiestos con Helm template
RELEASE_NAME="microservicio-app-${ENVIRONMENT}"
MANIFEST_FILE="${OUTPUT_DIR}/microservicio-app-${ENVIRONMENT}.yaml"

log "Generando manifiestos YAML: $MANIFEST_FILE"

helm template "$RELEASE_NAME" . \
    --namespace "$NAMESPACE" \
    --values values.yaml \
    --values "$HELM_VALUES_FILE" \
    > "$MANIFEST_FILE"

# Generar archivo de información
INFO_FILE="${OUTPUT_DIR}/deployment-info.txt"

cat > "$INFO_FILE" << EOF
MICROSERVICIO APP - INFORMACIÓN DE DESPLIEGUE
============================================

Ambiente: ${ENVIRONMENT}
Generado: $(date)
Release: ${RELEASE_NAME}
Namespace: ${NAMESPACE}

CONFIGURACIÓN:
- Imagen: ${IMAGE_REGISTRY}/${IMAGE_REPOSITORY}:${IMAGE_TAG}
- Réplicas: ${REPLICA_COUNT}
- Recursos: ${CPU_REQUEST}/${CPU_LIMIT} CPU, ${MEMORY_REQUEST}/${MEMORY_LIMIT} Memory
- ConfigMap: ${CONFIGMAP_ENABLED}
- Ingress: ${INGRESS_ENABLED}
- HPA: ${HPA_ENABLED}
- ServiceAccount: ${SERVICEACCOUNT_ENABLED}
- PDB: ${PDB_ENABLED}

ARCHIVOS GENERADOS:
- values-override-${ENVIRONMENT}.yaml (valores Helm)
- microservicio-app-${ENVIRONMENT}.yaml (manifiestos K8s)
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