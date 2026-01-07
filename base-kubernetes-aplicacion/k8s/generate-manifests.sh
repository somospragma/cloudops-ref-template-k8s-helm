#!/bin/bash

##############################################################################
# KUBERNETES APPLICATION MANIFEST GENERATOR V2
##############################################################################
# Script para generar manifiestos YAML usando Helm template
# Compatible con la estructura actual del proyecto
# Uso: ./generate-manifests.sh <ambiente> [output-dir]
# Ejemplo: ./generate-manifests.sh dev ./manifests-output
##############################################################################

set -e

# Colores para output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

# Variables globales
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)

log() {
    echo -e "${BLUE}[$(date +'%Y-%m-%d %H:%M:%S')]${NC} $1"
}

success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

header() {
    echo ""
    echo -e "${CYAN}========================================${NC}"
    echo -e "${CYAN}$1${NC}"
    echo -e "${CYAN}========================================${NC}"
}

# Mostrar banner
show_banner() {
    echo ""
    echo -e "${CYAN}╔════════════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║                                                        ║${NC}"
    echo -e "${CYAN}║          🔧 KUBERNETES MANIFEST GENERATOR 🔧           ║${NC}"
    echo -e "${CYAN}║                                                        ║${NC}"
    echo -e "${CYAN}║      Genera manifiestos YAML usando Helm template      ║${NC}"
    echo -e "${CYAN}║                                                        ║${NC}"
    echo -e "${CYAN}╚════════════════════════════════════════════════════════╝${NC}"
    echo ""
}

# Validar argumentos
if [ $# -eq 0 ]; then
    show_banner
    echo "${CYAN}Uso:${NC} $0 <ambiente> [output-dir]"
    echo "${CYAN}Ambientes:${NC} dev, staging, prod"
    echo "${CYAN}Ejemplo:${NC} $0 dev ./manifests-output"
    echo ""
    echo "${CYAN}Descripción:${NC}"
    echo "  Genera manifiestos de Kubernetes usando Helm template"
    echo "  Incluye configuración de Spring Boot desde app/application.yaml"
    echo "  Usa variables de ambiente desde .env.<ambiente>"
    echo ""
    exit 1
fi

ENVIRONMENT=$1
OUTPUT_DIR=${2:-"./manifests-${ENVIRONMENT}"}
ENV_FILE="${SCRIPT_DIR}/.env.${ENVIRONMENT}"

show_banner

# Validar prerequisitos
header "VALIDANDO PREREQUISITOS"

# Verificar helm
if ! command -v helm &> /dev/null; then
    error "helm no está instalado"
    log "Instala Helm desde: https://helm.sh/docs/intro/install/"
    exit 1
fi
success "helm instalado: $(helm version --short)"

# Verificar Chart.yaml
if [ ! -f "${SCRIPT_DIR}/Chart.yaml" ]; then
    error "No se encuentra Chart.yaml en ${SCRIPT_DIR}"
    exit 1
fi
success "Chart.yaml encontrado"

# Verificar values.yaml
if [ ! -f "${SCRIPT_DIR}/values.yaml" ]; then
    error "No se encuentra values.yaml en ${SCRIPT_DIR}"
    exit 1
fi
success "values.yaml encontrado"

# Verificar application.yaml
if [ ! -f "${SCRIPT_DIR}/../app/application.yaml" ]; then
    error "No se encuentra app/application.yaml"
    exit 1
fi
success "app/application.yaml encontrado"

# Validar archivo de ambiente
if [ ! -f "$ENV_FILE" ]; then
    error "Archivo de ambiente no encontrado: $ENV_FILE"
    log "Archivos disponibles:"
    ls -la "${SCRIPT_DIR}"/.env.* 2>/dev/null || echo "  No hay archivos .env.*"
    exit 1
fi
success "Archivo de ambiente encontrado: $(basename $ENV_FILE)"

header "CONFIGURACIÓN"
log "Ambiente: ${ENVIRONMENT}"
log "Directorio de salida: ${OUTPUT_DIR}"
log "Archivo de variables: ${ENV_FILE}"

# Crear directorio de salida (limpiar si existe)
if [ -d "$OUTPUT_DIR" ]; then
    rm -rf "$OUTPUT_DIR"
fi
mkdir -p "$OUTPUT_DIR"

# Crear symlink latest
latest_link="${SCRIPT_DIR}/manifests-latest"
if [ -L "$latest_link" ]; then
    rm "$latest_link"
fi
ln -sf "$OUTPUT_DIR" "$latest_link"

# Cargar variables de ambiente
log "Cargando variables de ambiente..."
set -a
source "$ENV_FILE"
set +a
success "Variables cargadas desde $(basename $ENV_FILE)"

header "GENERANDO VALORES OVERRIDE"

# Generar archivo de valores override
HELM_VALUES_FILE="${OUTPUT_DIR}/values-override-${ENVIRONMENT}.yaml"

log "Generando valores override: $(basename $HELM_VALUES_FILE)"

cat > "$HELM_VALUES_FILE" << EOF
# =====================================================
# VALORES OVERRIDE PARA AMBIENTE: ${ENVIRONMENT}
# =====================================================
# Generado automáticamente el: $(date)
# Desde archivo: $(basename $ENV_FILE)
# =====================================================

# Información básica
appName: microservicio-app
namespace: ${NAMESPACE}
environment: ${ENVIRONMENT}

# Configuración de imagen
image:
  registry: ${IMAGE_REGISTRY}
  repository: ${IMAGE_REPOSITORY}
  tag: "${IMAGE_TAG}"

# Número de réplicas
replicaCount: ${REPLICA_COUNT}

# Recursos computacionales
resources:
  requests:
    memory: "${MEMORY_REQUEST}"
    cpu: "${CPU_REQUEST}"
  limits:
    memory: "${MEMORY_LIMIT}"
    cpu: "${CPU_LIMIT}"

# Configuración del servicio
service:
  port: ${SERVICE_PORT}

# ConfigMap (configuración de aplicación)
configMap:
  enabled: ${CONFIGMAP_ENABLED}

# Configuración de Ingress
ingress:
  enabled: ${INGRESS_ENABLED}
  className: ${INGRESS_CLASS_NAME}
  
  # Configuración de grupo ALB
  group:
    enabled: ${INGRESS_GROUP_ENABLED:-false}
  
  # Reglas de enrutamiento
  rules:
    - host: "${INGRESS_HOST:-}"
      paths:
        - path: ${INGRESS_PATH}
          pathType: Prefix
          servicePort: ${SERVICE_PORT}
  
  # Annotations para controladores
  annotations:
    awsHealthcheckPath: "${INGRESS_HEALTHCHECK_PATH:-/}"
    awsGroupName: "${INGRESS_GROUP_NAME:-}"
    awsListenPorts: '${INGRESS_LISTEN_PORTS:-}'
    awsTargetType: "${INGRESS_TARGET_TYPE:-ip}"
    awsBackendProtocol: "${INGRESS_BACKEND_PROTOCOL:-HTTP}"
    awsSuccessCodes: "${INGRESS_SUCCESS_CODES:-200}"
    custom: {}
  


# Horizontal Pod Autoscaler
hpa:
  enabled: ${HPA_ENABLED}
  minReplicas: ${HPA_MIN_REPLICAS}
  maxReplicas: ${HPA_MAX_REPLICAS}
  targetCPUUtilizationPercentage: ${HPA_TARGET_CPU}
  targetMemoryUtilizationPercentage: ${HPA_TARGET_MEMORY}

# Service Account (IRSA)
serviceAccount:
  enabled: ${SERVICEACCOUNT_ENABLED}
  annotations:
    irsaRoleArn: "${SERVICEACCOUNT_IRSA_ROLE_ARN:-}"

# Pod Disruption Budget
pdb:
  enabled: ${PDB_ENABLED}
  minAvailable: ${PDB_MIN_AVAILABLE}
  maxUnavailable: "${PDB_MAX_UNAVAILABLE:-}"
EOF

success "Valores override generados"

header "GENERANDO MANIFIESTOS KUBERNETES"

# Configurar nombres
RELEASE_NAME="microservicio-app"
MANIFEST_FILE="${OUTPUT_DIR}/all-manifests.yaml"
APP_CONFIG_FILE="${SCRIPT_DIR}/../app/application.yaml"

log "Release name: ${RELEASE_NAME}"
log "Namespace: ${NAMESPACE}"
log "Manifest file: $(basename $MANIFEST_FILE)"

# Generar manifiestos con Helm template
log "Ejecutando helm template..."

if helm template "$RELEASE_NAME" "${SCRIPT_DIR}" \
    --namespace "$NAMESPACE" \
    --values "${SCRIPT_DIR}/values.yaml" \
    --values "$APP_CONFIG_FILE" \
    --values "$HELM_VALUES_FILE" \
    > "$MANIFEST_FILE"; then
    success "Manifiestos generados: $(basename $MANIFEST_FILE)"
else
    error "Error al generar manifiestos con Helm"
    exit 1
fi

# Separar manifiestos en archivos individuales
log "Separando manifiestos en archivos individuales..."

# Función para separar manifiestos
separate_manifests() {
    local input_file="$1"
    local output_dir="$2"
    local current_file=""
    local current_kind=""
    
    while IFS= read -r line || [ -n "$line" ]; do
        # Detectar separador de recursos
        if [[ "$line" =~ ^---[[:space:]]*$ ]]; then
            continue
        fi
        
        # Detectar tipo de recurso
        if [[ "$line" =~ ^kind:[[:space:]]*(.*) ]]; then
            current_kind="${BASH_REMATCH[1]}"
            current_kind=$(echo "$current_kind" | tr '[:upper:]' '[:lower:]')
            current_file="${output_dir}/${current_kind}.yaml"
            
            # Agregar separador si el archivo ya existe
            if [ -f "$current_file" ]; then
                echo "---" >> "$current_file"
            fi
        fi
        
        # Escribir línea al archivo actual
        if [ -n "$current_file" ]; then
            echo "$line" >> "$current_file"
        fi
        
    done < "$input_file"
    
    return 0
}

if separate_manifests "$MANIFEST_FILE" "$OUTPUT_DIR"; then
    success "Manifiestos separados"
else
    warning "Error al separar manifiestos, pero all-manifests.yaml está disponible"
fi

header "GENERANDO INFORMACIÓN DE DEPLOYMENT"

# Generar archivo de información
INFO_FILE="${OUTPUT_DIR}/deployment-info.txt"

log "Generando información de deployment..."

cat > "$INFO_FILE" << EOF
╔════════════════════════════════════════════════════════╗
║                                                        ║
║           MICROSERVICIO APP - DEPLOYMENT INFO         ║
║                                                        ║
╚════════════════════════════════════════════════════════╝

AMBIENTE: ${ENVIRONMENT}
GENERADO: $(date)
RELEASE: ${RELEASE_NAME}
NAMESPACE: ${NAMESPACE}

════════════════════════════════════════════════════════
CONFIGURACIÓN DE LA APLICACIÓN
════════════════════════════════════════════════════════

IMAGEN:
  Registry: ${IMAGE_REGISTRY}
  Repository: ${IMAGE_REPOSITORY}
  Tag: ${IMAGE_TAG}
  Imagen completa: ${IMAGE_REGISTRY}/${IMAGE_REPOSITORY}:${IMAGE_TAG}

RECURSOS:
  Réplicas: ${REPLICA_COUNT}
  CPU Request: ${CPU_REQUEST}
  CPU Limit: ${CPU_LIMIT}
  Memory Request: ${MEMORY_REQUEST}
  Memory Limit: ${MEMORY_LIMIT}

COMPONENTES HABILITADOS:
  ConfigMap: ${CONFIGMAP_ENABLED}
  Ingress: ${INGRESS_ENABLED}
  HPA: ${HPA_ENABLED}
  ServiceAccount: ${SERVICEACCOUNT_ENABLED}
  PDB: ${PDB_ENABLED}

════════════════════════════════════════════════════════
ARCHIVOS GENERADOS
════════════════════════════════════════════════════════

📁 Directorio: ${OUTPUT_DIR}
📄 all-manifests.yaml - Todos los recursos juntos
📄 deployment.yaml - Deployment de la aplicación
📄 service.yaml - Service interno
📄 configmap.yaml - Configuración de la aplicación
📄 ingress.yaml - Exposición externa
📄 hpa.yaml - Auto-escalado horizontal
📄 serviceaccount.yaml - Cuenta de servicio IRSA
📄 pdb.yaml - Presupuesto de disrupción
📄 values-override-${ENVIRONMENT}.yaml - Valores Helm
📄 deployment-info.txt - Esta información

════════════════════════════════════════════════════════
COMANDOS PARA APLICAR
════════════════════════════════════════════════════════

# Aplicar todos los manifiestos:
kubectl apply -f ${OUTPUT_DIR}/all-manifests.yaml

# Aplicar recursos individuales:
kubectl apply -f ${OUTPUT_DIR}/deployment.yaml
kubectl apply -f ${OUTPUT_DIR}/service.yaml
kubectl apply -f ${OUTPUT_DIR}/configmap.yaml

# Usar el script de despliegue:
./deployment.sh deploy --env ${ENVIRONMENT}

# Validar antes de aplicar:
kubectl apply --dry-run=client -f ${OUTPUT_DIR}/all-manifests.yaml

# Ver diferencias con deployment actual:
kubectl diff -f ${OUTPUT_DIR}/all-manifests.yaml

════════════════════════════════════════════════════════
VERIFICACIÓN POST-DEPLOYMENT
════════════════════════════════════════════════════════

# Ver estado de los recursos:
kubectl get all -n ${NAMESPACE} -l app=microservicio-app

# Ver logs:
kubectl logs -f deployment/microservicio-app-deploy -n ${NAMESPACE}

# Port-forward para testing:
kubectl port-forward service/microservicio-app-svc 8080:80 -n ${NAMESPACE}

EOF

success "Información de deployment generada"

header "RESUMEN FINAL"

success "¡Manifiestos generados exitosamente!"
warning "Directorio de salida: ${OUTPUT_DIR}"
warning "Symlink latest: ${SCRIPT_DIR}/manifests-latest"

# Mostrar resumen de archivos
echo ""
log "Archivos generados:"
if [ -d "$OUTPUT_DIR" ]; then
    local file_count=0
    for file in "${OUTPUT_DIR}"/*.yaml "${OUTPUT_DIR}"/*.txt; do
        if [ -f "$file" ]; then
            ((file_count++))
            local filename=$(basename "$file")
            local filesize=$(du -h "$file" | cut -f1)
            local lines=$(wc -l < "$file" 2>/dev/null || echo "0")
            echo "  ${file_count}. ${filename} (${filesize}, ${lines} líneas)"
        fi
    done
    echo ""
    success "Total de archivos: ${file_count}"
fi

echo ""
header "PRÓXIMOS PASOS"
echo -e "${CYAN}1. Revisar manifiestos:${NC}"
echo "   cd ${OUTPUT_DIR}"
echo "   cat all-manifests.yaml"
echo ""
echo -e "${CYAN}2. Validar sintaxis:${NC}"
echo "   kubectl apply --dry-run=client -f ${OUTPUT_DIR}/all-manifests.yaml"
echo ""
echo -e "${CYAN}3. Aplicar manifiestos:${NC}"
echo "   kubectl apply -f ${OUTPUT_DIR}/all-manifests.yaml"
echo ""
echo -e "${CYAN}4. O usar script de deployment:${NC}"
echo "   ./deployment.sh deploy --env ${ENVIRONMENT}"
echo ""