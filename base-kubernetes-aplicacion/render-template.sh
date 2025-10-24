#!/bin/bash

##############################################################################
# Script para Renderizar Templates de Helm sin Desplegar
# Este script toma los templates y los renderiza con las variables,
# guardando los archivos YAML resultantes en un directorio de salida
##############################################################################

set -e  # Salir si ocurre algún error

# Colores para output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Variables globales
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CHART_PATH="${SCRIPT_DIR}/k8s"
ENVIRONMENT=""
ENV_FILE=""
OUTPUT_DIR="${SCRIPT_DIR}/rendered-manifests"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)

##############################################################################
# FUNCIONES
##############################################################################

# Función para imprimir mensajes
print_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

print_header() {
    echo ""
    echo -e "${CYAN}========================================${NC}"
    echo -e "${CYAN}$1${NC}"
    echo -e "${CYAN}========================================${NC}"
}

# Función para mostrar banner
show_banner() {
    echo ""
    echo -e "${CYAN}╔════════════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║                                                        ║${NC}"
    echo -e "${CYAN}║        🔧 HELM TEMPLATE RENDERER 🔧                   ║${NC}"
    echo -e "${CYAN}║                                                        ║${NC}"
    echo -e "${CYAN}║  Renderiza templates sin desplegar a Kubernetes       ║${NC}"
    echo -e "${CYAN}║                                                        ║${NC}"
    echo -e "${CYAN}╚════════════════════════════════════════════════════════╝${NC}"
    echo ""
}

# Función para validar prerequisitos
check_prerequisites() {
    print_info "Validando prerequisitos..."
    
    # Verificar helm
    if ! command -v helm &> /dev/null; then
        print_error "helm no está instalado"
        print_info "Instala Helm desde: https://helm.sh/docs/intro/install/"
        exit 1
    fi
    print_success "helm instalado: $(helm version --short)"
    
    # Verificar que existe el directorio del chart
    if [ ! -d "${CHART_PATH}" ]; then
        print_error "No se encuentra el directorio del chart: ${CHART_PATH}"
        exit 1
    fi
    print_success "Directorio del chart encontrado: ${CHART_PATH}"
    
    # Verificar que existe Chart.yaml
    if [ ! -f "${CHART_PATH}/Chart.yaml" ]; then
        print_error "No se encuentra Chart.yaml en ${CHART_PATH}"
        exit 1
    fi
    print_success "Chart.yaml encontrado"
    
    # Verificar que existe values.yaml
    if [ ! -f "${CHART_PATH}/values.yaml" ]; then
        print_error "No se encuentra values.yaml en ${CHART_PATH}"
        exit 1
    fi
    print_success "values.yaml encontrado"
}

# Función para cargar variables de entorno
load_environment() {
    if [ -f "${ENV_FILE}" ]; then
        print_info "Ambiente: ${ENVIRONMENT}"
        print_info "Cargando variables desde ${ENV_FILE}..."
        set -a
        source "${ENV_FILE}"
        set +a
        print_success "Variables de entorno cargadas: $(basename ${ENV_FILE})"
    else
        print_warning "Archivo de ambiente no encontrado: ${ENV_FILE}"
        print_info "Se usarán los valores por defecto de values.yaml"
        print_info "Uso: ./render-template.sh --env dev"
    fi
}

# Función para crear directorio de salida
create_output_directory() {
    local dir_name="${OUTPUT_DIR}_${TIMESTAMP}"
    
    print_info "Creando directorio de salida: ${dir_name}"
    mkdir -p "${dir_name}"
    
    # Crear symlink "latest" apuntando al directorio más reciente
    if [ -L "${OUTPUT_DIR}" ]; then
        rm "${OUTPUT_DIR}"
    fi
    ln -sf "${dir_name}" "${OUTPUT_DIR}"
    
    OUTPUT_DIR="${dir_name}"
    print_success "Directorio creado: ${OUTPUT_DIR}"
}

# Función para mostrar variables que se usarán
show_variables() {
    print_header "VARIABLES QUE SE USARÁN"
    
    echo -e "${CYAN}Aplicación:${NC}"
    echo "  - Nombre: ${APP_NAME}"
    echo "  - Namespace: ${NAMESPACE}"
    echo "  - Release: ${RELEASE_NAME}"
    echo ""
    
    echo -e "${CYAN}Imagen:${NC}"
    echo "  - Registry: ${IMAGE_REGISTRY}"
    echo "  - Repository: ${IMAGE_REPOSITORY}"
    echo "  - Tag: ${IMAGE_TAG}"
    echo "  - Imagen completa: ${IMAGE_REGISTRY}/${IMAGE_REPOSITORY}:${IMAGE_TAG}"
    echo ""
    
    echo -e "${CYAN}Recursos:${NC}"
    echo "  - Réplicas: ${REPLICA_COUNT:-2}"
    echo "  - Memory Request: ${MEMORY_REQUEST:-128Mi}"
    echo "  - CPU Request: ${CPU_REQUEST:-100m}"
    echo "  - Memory Limit: ${MEMORY_LIMIT:-256Mi}"
    echo "  - CPU Limit: ${CPU_LIMIT:-200m}"
    echo ""
    
    if [ -n "${INGRESS_HOST}" ]; then
        echo -e "${CYAN}Networking:${NC}"
        echo "  - Ingress Host: ${INGRESS_HOST}"
        echo "  - Service Port: ${SERVICE_PORT:-80}"
        echo ""
    fi
}

# Función para renderizar templates
render_templates() {
    print_header "RENDERIZANDO TEMPLATES"
    
    print_info "Ejecutando 'helm template'..."
    
    # Construir comando helm con todas las variables
    local helm_cmd=(
        helm template
        "${RELEASE_NAME}"
        "${CHART_PATH}"
        -f "${CHART_PATH}/values.yaml"
        -f "${SCRIPT_DIR}/app/application.yaml"
        --namespace "${NAMESPACE}"
        --set "appName=${APP_NAME}"
        --set "namespace=${NAMESPACE}"
        --set "image.registry=${IMAGE_REGISTRY}"
        --set "image.repository=${IMAGE_REPOSITORY}"
        --set "image.tag=${IMAGE_TAG}"
    )

    # Agregar variables opcionales si existen
    if [ -n "${REPLICA_COUNT}" ]; then
        helm_cmd+=(--set "replicaCount=${REPLICA_COUNT}")
    fi

    if [ -n "${MEMORY_REQUEST}" ]; then
        helm_cmd+=(--set "resources.requests.memory=${MEMORY_REQUEST}")
    fi

    if [ -n "${CPU_REQUEST}" ]; then
        helm_cmd+=(--set "resources.requests.cpu=${CPU_REQUEST}")
    fi

    if [ -n "${MEMORY_LIMIT}" ]; then
        helm_cmd+=(--set "resources.limits.memory=${MEMORY_LIMIT}")
    fi

    if [ -n "${CPU_LIMIT}" ]; then
        helm_cmd+=(--set "resources.limits.cpu=${CPU_LIMIT}")
    fi

    if [ -n "${SERVICE_PORT}" ]; then
        helm_cmd+=(--set "service.port=${SERVICE_PORT}")
    fi

    # ConfigMap enabled
    if [ -n "${CONFIGMAP_ENABLED}" ]; then
        helm_cmd+=(--set "configMap.enabled=${CONFIGMAP_ENABLED}")
    fi

    # Ingress configuration
    if [ -n "${INGRESS_ENABLED}" ]; then
        helm_cmd+=(--set "ingress.enabled=${INGRESS_ENABLED}")
    fi

    if [ -n "${INGRESS_CLASS_NAME}" ]; then
        helm_cmd+=(--set "ingress.className=${INGRESS_CLASS_NAME}")
    fi

    if [ -n "${INGRESS_HOST}" ]; then
        helm_cmd+=(--set "ingress.rules[0].host=${INGRESS_HOST}")
    fi

    if [ -n "${INGRESS_PATH}" ]; then
        helm_cmd+=(--set "ingress.rules[0].paths[0].path=${INGRESS_PATH}")
    fi

    if [ -n "${INGRESS_REWRITE_TARGET}" ]; then
        helm_cmd+=(--set "ingress.annotations.rewriteTarget=${INGRESS_REWRITE_TARGET}")
    fi

    # Ingress TLS configuration
    if [ -n "${INGRESS_TLS_ENABLED}" ]; then
        helm_cmd+=(--set "ingress.tls.enabled=${INGRESS_TLS_ENABLED}")
    fi

    if [ -n "${INGRESS_TLS_HOSTS}" ]; then
        helm_cmd+=(--set "ingress.tls.hosts[0]=${INGRESS_TLS_HOSTS}")
    fi

    if [ -n "${INGRESS_TLS_SECRET_NAME}" ]; then
        helm_cmd+=(--set "ingress.tls.secretName=${INGRESS_TLS_SECRET_NAME}")
    fi

    # Ingress mTLS configuration
    if [ -n "${INGRESS_MTLS_ENABLED}" ]; then
        helm_cmd+=(--set "ingress.mtls.enabled=${INGRESS_MTLS_ENABLED}")
    fi

    if [ -n "${INGRESS_MTLS_SECRET_NAME}" ]; then
        helm_cmd+=(--set "ingress.mtls.secretName=${INGRESS_MTLS_SECRET_NAME}")
    fi

    if [ -n "${INGRESS_MTLS_VERIFY_CLIENT}" ]; then
        helm_cmd+=(--set "ingress.mtls.verifyClient=${INGRESS_MTLS_VERIFY_CLIENT}")
    fi

    # HPA (Horizontal Pod Autoscaler) configuration
    if [ -n "${HPA_ENABLED}" ]; then
        helm_cmd+=(--set "hpa.enabled=${HPA_ENABLED}")
    fi

    if [ -n "${HPA_MIN_REPLICAS}" ]; then
        helm_cmd+=(--set "hpa.minReplicas=${HPA_MIN_REPLICAS}")
    fi

    if [ -n "${HPA_MAX_REPLICAS}" ]; then
        helm_cmd+=(--set "hpa.maxReplicas=${HPA_MAX_REPLICAS}")
    fi

    if [ -n "${HPA_TARGET_CPU}" ]; then
        helm_cmd+=(--set "hpa.targetCPUUtilizationPercentage=${HPA_TARGET_CPU}")
    fi

    if [ -n "${HPA_TARGET_MEMORY}" ]; then
        helm_cmd+=(--set "hpa.targetMemoryUtilizationPercentage=${HPA_TARGET_MEMORY}")
    fi

    # ServiceAccount configuration
    if [ -n "${SERVICEACCOUNT_ENABLED}" ]; then
        helm_cmd+=(--set "serviceAccount.enabled=${SERVICEACCOUNT_ENABLED}")
    fi

    if [ -n "${SERVICEACCOUNT_IRSA_ROLE_ARN}" ]; then
        helm_cmd+=(--set "serviceAccount.annotations.irsaRoleArn=${SERVICEACCOUNT_IRSA_ROLE_ARN}")
    fi

    if [ -n "${SERVICEACCOUNT_AZURE_CLIENT_ID}" ]; then
        helm_cmd+=(--set "serviceAccount.annotations.azureClientId=${SERVICEACCOUNT_AZURE_CLIENT_ID}")
    fi

    # PDB (Pod Disruption Budget) configuration
    if [ -n "${PDB_ENABLED}" ]; then
        helm_cmd+=(--set "pdb.enabled=${PDB_ENABLED}")
    fi

    if [ -n "${PDB_MIN_AVAILABLE}" ]; then
        helm_cmd+=(--set "pdb.minAvailable=${PDB_MIN_AVAILABLE}")
    fi

    if [ -n "${PDB_MAX_UNAVAILABLE}" ]; then
        helm_cmd+=(--set "pdb.maxUnavailable=${PDB_MAX_UNAVAILABLE}")
    fi

    # Ejecutar helm template y guardar en archivo completo
    print_info "Generando manifiestos completos..."
    if "${helm_cmd[@]}" > "${OUTPUT_DIR}/all-manifests.yaml"; then
        print_success "Manifiestos completos generados: ${OUTPUT_DIR}/all-manifests.yaml"
    else
        print_error "Error al renderizar templates"
        exit 1
    fi
    
    # Separar los manifiestos en archivos individuales
    print_info "Separando manifiestos en archivos individuales..."
    split_manifests
    
    print_success "Templates renderizados exitosamente"
}

# Función para separar manifiestos en archivos individuales
split_manifests() {
    local input_file="${OUTPUT_DIR}/all-manifests.yaml"
    local current_file=""
    local current_kind=""
    local line_num=0
    
    while IFS= read -r line || [ -n "$line" ]; do
        ((line_num++))
        
        # Detectar inicio de un nuevo recurso
        if [[ "$line" =~ ^---[[:space:]]*$ ]] || [[ $line_num -eq 1 ]]; then
            if [[ $line_num -gt 1 ]]; then
                continue
            fi
        fi
        
        # Detectar el tipo de recurso (kind)
        if [[ "$line" =~ ^kind:[[:space:]]*(.*) ]]; then
            current_kind="${BASH_REMATCH[1]}"
            current_kind=$(echo "$current_kind" | tr '[:upper:]' '[:lower:]')
            current_file="${OUTPUT_DIR}/${current_kind}.yaml"
            
            # Si el archivo ya existe, agregar separador
            if [ -f "$current_file" ]; then
                echo "---" >> "$current_file"
            fi
        fi
        
        # Escribir línea al archivo actual
        if [ -n "$current_file" ]; then
            echo "$line" >> "$current_file"
        fi
        
    done < "$input_file"
    
    print_success "Manifiestos separados en archivos individuales"
}

# Función para mostrar resumen
show_summary() {
    print_header "RESUMEN DE ARCHIVOS GENERADOS"
    
    echo -e "${CYAN}Directorio de salida:${NC} ${OUTPUT_DIR}"
    echo ""
    
    # Listar archivos generados
    if [ -d "${OUTPUT_DIR}" ]; then
        local file_count=0
        echo -e "${CYAN}Archivos generados:${NC}"
        for file in "${OUTPUT_DIR}"/*.yaml; do
            if [ -f "$file" ]; then
                ((file_count++))
                local filename=$(basename "$file")
                local filesize=$(du -h "$file" | cut -f1)
                local lines=$(wc -l < "$file")
                echo "  ${file_count}. ${filename}"
                echo "     - Tamaño: ${filesize}"
                echo "     - Líneas: ${lines}"
            fi
        done
        echo ""
        print_success "Total de archivos: ${file_count}"
    else
        print_error "No se encontró el directorio de salida"
    fi
}

# Función para mostrar instrucciones de revisión
show_review_instructions() {
    print_header "PRÓXIMOS PASOS"
    
    echo -e "${CYAN}1. Revisar los archivos generados:${NC}"
    echo "   cd ${OUTPUT_DIR}"
    echo "   ls -la"
    echo ""
    
    echo -e "${CYAN}2. Ver todos los manifiestos juntos:${NC}"
    echo "   cat ${OUTPUT_DIR}/all-manifests.yaml"
    echo ""
    
    echo -e "${CYAN}3. Ver un archivo específico:${NC}"
    echo "   cat ${OUTPUT_DIR}/deployment.yaml"
    echo "   cat ${OUTPUT_DIR}/service.yaml"
    echo "   cat ${OUTPUT_DIR}/ingress.yaml"
    echo ""
    
    echo -e "${CYAN}4. Validar los manifiestos (requiere conexión a cluster):${NC}"
    echo "   kubectl apply --dry-run=client -f ${OUTPUT_DIR}/all-manifests.yaml"
    echo ""
    
    echo -e "${CYAN}5. Ver diferencias con el deployment actual:${NC}"
    echo "   kubectl diff -f ${OUTPUT_DIR}/all-manifests.yaml"
    echo ""
    
    echo -e "${CYAN}6. Si todo se ve bien, desplegar:${NC}"
    echo "   ./deploy.sh deploy"
    echo ""
}

# Función para abrir archivos en editor (opcional)
open_in_editor() {
    print_info "¿Deseas abrir los archivos en un editor? (y/n)"
    read -r response
    
    if [[ "$response" =~ ^[Yy]$ ]]; then
        # Detectar editor disponible
        if command -v code &> /dev/null; then
            print_info "Abriendo en VS Code..."
            code "${OUTPUT_DIR}"
        elif command -v nano &> /dev/null; then
            print_info "Abriendo all-manifests.yaml en nano..."
            nano "${OUTPUT_DIR}/all-manifests.yaml"
        elif command -v vim &> /dev/null; then
            print_info "Abriendo all-manifests.yaml en vim..."
            vim "${OUTPUT_DIR}/all-manifests.yaml"
        else
            print_warning "No se encontró editor disponible"
            print_info "Puedes abrir manualmente: ${OUTPUT_DIR}"
        fi
    fi
}

# Función para comparar con valores por defecto
compare_with_defaults() {
    print_header "COMPARACIÓN CON VALUES POR DEFECTO"
    
    print_info "Renderizando con valores por defecto para comparación..."
    
    # Crear directorio temporal para valores por defecto
    local temp_dir=$(mktemp -d)
    
    helm template "${RELEASE_NAME}" "${CHART_PATH}" \
        --namespace "${NAMESPACE}" \
        > "${temp_dir}/defaults.yaml" 2>/dev/null
    
    # Comparar si hay diferencias
    if command -v diff &> /dev/null; then
        print_info "Diferencias encontradas:"
        if diff -u "${temp_dir}/defaults.yaml" "${OUTPUT_DIR}/all-manifests.yaml" > "${OUTPUT_DIR}/diff-with-defaults.txt"; then
            print_info "No hay diferencias con los valores por defecto"
        else
            print_success "Diferencias guardadas en: ${OUTPUT_DIR}/diff-with-defaults.txt"
            echo ""
            echo "Previsualización de cambios (primeras 20 líneas):"
            head -n 20 "${OUTPUT_DIR}/diff-with-defaults.txt"
            echo "..."
        fi
    fi
    
    # Limpiar temporal
    rm -rf "${temp_dir}"
}

# Función para mostrar ayuda
show_help() {
    cat << EOF
${CYAN}Uso: ./render-templates.sh [OPCIONES]${NC}

Script para renderizar templates de Helm sin desplegar a Kubernetes.
Útil para revisar cómo quedan los manifiestos antes de aplicarlos.

${CYAN}OPCIONES:${NC}
    render          Renderiza los templates (opción por defecto)
    clean           Limpia todos los directorios de manifiestos generados
    help            Muestra esta ayuda

${CYAN}VARIABLES DE ENTORNO (definir en archivo .env):${NC}
    APP_NAME              Nombre de la aplicación
    NAMESPACE             Namespace de Kubernetes
    IMAGE_REGISTRY        Registry de la imagen
    IMAGE_REPOSITORY      Repositorio de la imagen
    IMAGE_TAG             Tag de la imagen
    REPLICA_COUNT         Número de réplicas
    MEMORY_REQUEST        Memory request
    CPU_REQUEST           CPU request
    MEMORY_LIMIT          Memory limit
    CPU_LIMIT             CPU limit
    INGRESS_HOST          Host del Ingress
    SERVICE_PORT          Puerto del servicio

${CYAN}EJEMPLOS:${NC}
    # Renderizar templates con valores del .env
    ./render-templates.sh

    # Renderizar templates
    ./render-templates.sh render

    # Limpiar archivos generados
    ./render-templates.sh clean

    # Ver ayuda
    ./render-templates.sh help

${CYAN}SALIDA:${NC}
    Los manifiestos se guardan en: rendered-manifests_YYYYMMDD_HHMMSS/
    Se crea un symlink 'rendered-manifests' que apunta a la versión más reciente

EOF
}

# Función para limpiar manifiestos generados
clean_manifests() {
    print_warning "¿Estás seguro de eliminar todos los manifiestos generados? (yes/no)"
    read -r confirmation
    
    if [ "${confirmation}" = "yes" ]; then
        print_info "Eliminando manifiestos generados..."
        rm -rf "${SCRIPT_DIR}"/rendered-manifests_*
        rm -f "${SCRIPT_DIR}/rendered-manifests"
        print_success "Manifiestos eliminados"
    else
        print_info "Operación cancelada"
    fi
}

##############################################################################
# FUNCIÓN PRINCIPAL
##############################################################################

main() {
    local action="render"

    # Parsear argumentos
    while [[ $# -gt 0 ]]; do
        case $1 in
            --env)
                ENVIRONMENT="$2"
                shift 2
                ;;
            render|clean|help|--help|-h)
                action="$1"
                shift
                ;;
            *)
                # Si el primer argumento no empieza con --, asumimos que es la acción
                if [[ ! "$1" =~ ^-- ]] && [[ -z "$action_set" ]]; then
                    action="$1"
                    action_set="true"
                fi
                shift
                ;;
        esac
    done

    # Determinar archivo de ambiente
    if [ -n "${ENVIRONMENT}" ]; then
        ENV_FILE="${SCRIPT_DIR}/.env.${ENVIRONMENT}"
    else
        # Buscar en orden: .env.dev, .env.staging, .env.prod, .env
        if [ -f "${SCRIPT_DIR}/.env.dev" ]; then
            ENV_FILE="${SCRIPT_DIR}/.env.dev"
            ENVIRONMENT="dev"
        elif [ -f "${SCRIPT_DIR}/.env.staging" ]; then
            ENV_FILE="${SCRIPT_DIR}/.env.staging"
            ENVIRONMENT="staging"
        elif [ -f "${SCRIPT_DIR}/.env.prod" ]; then
            ENV_FILE="${SCRIPT_DIR}/.env.prod"
            ENVIRONMENT="prod"
        elif [ -f "${SCRIPT_DIR}/.env" ]; then
            ENV_FILE="${SCRIPT_DIR}/.env"
            ENVIRONMENT="default"
        fi
    fi

    show_banner

    case "${action}" in
        render)
            check_prerequisites
            load_environment
            
            # Configurar variables
            APP_NAME="${APP_NAME:-microservicio-app}"
            NAMESPACE="${NAMESPACE:-default}"
            RELEASE_NAME="${APP_NAME}"
            IMAGE_REGISTRY="${IMAGE_REGISTRY:-docker.io}"
            IMAGE_REPOSITORY="${IMAGE_REPOSITORY:-nginx}"
            IMAGE_TAG="${IMAGE_TAG:-1.25-alpine}"
            
            show_variables
            create_output_directory
            render_templates
            compare_with_defaults
            show_summary
            show_review_instructions
            open_in_editor
            
            print_success "¡Proceso completado!"
            ;;
            
        clean)
            clean_manifests
            ;;
            
        help|--help|-h)
            show_help
            ;;
            
        *)
            print_error "Acción desconocida: ${action}"
            show_help
            exit 1
            ;;
    esac
}

##############################################################################
# EJECUCIÓN
##############################################################################

main "$@"