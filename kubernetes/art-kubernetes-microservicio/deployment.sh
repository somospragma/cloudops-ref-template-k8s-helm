#!/bin/bash

##############################################################################
# Script para Desplegar con Helm en Kubernetes
# Simula el flujo de Azure DevOps con Library Groups usando archivos .env
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
    echo -e "${CYAN}║           🚀 HELM DEPLOYMENT MANAGER 🚀               ║${NC}"
    echo -e "${CYAN}║                                                        ║${NC}"
    echo -e "${CYAN}║  Simula Azure DevOps con archivos de ambiente         ║${NC}"
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

    # Verificar kubectl
    if ! command -v kubectl &> /dev/null; then
        print_error "kubectl no está instalado"
        print_info "Instala kubectl desde: https://kubernetes.io/docs/tasks/tools/"
        exit 1
    fi
    print_success "kubectl instalado: $(kubectl version --client --short 2>/dev/null || echo 'Cliente OK')"

    # Verificar conexión al cluster
    if ! kubectl cluster-info &> /dev/null; then
        print_error "No hay conexión con el cluster de Kubernetes"
        print_info "Verifica tu configuración con: kubectl cluster-info"
        exit 1
    fi
    print_success "Conectado al cluster de Kubernetes"

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

# Función para cargar variables del archivo de ambiente
load_env_vars() {
    if [ -f "${ENV_FILE}" ]; then
        print_info "Cargando variables desde ${ENV_FILE}..."
        set -a
        source "${ENV_FILE}"
        set +a
        print_success "Variables de entorno cargadas: $(basename ${ENV_FILE})"
    else
        print_warning "No se encontró ${ENV_FILE}"
        print_info "Usando solo valores de values.yaml"
    fi
}

# Función para construir argumentos de Helm con override
build_helm_overrides() {
    local OVERRIDES=""

    # Si hay variables de entorno, construir --set arguments
    if [ -n "${NAMESPACE}" ]; then
        OVERRIDES="$OVERRIDES --set namespace=${NAMESPACE}"
    fi

    if [ -n "${REPLICA_COUNT}" ]; then
        OVERRIDES="$OVERRIDES --set replicaCount=${REPLICA_COUNT}"
    fi

    if [ -n "${IMAGE_REGISTRY}" ]; then
        OVERRIDES="$OVERRIDES --set image.registry=${IMAGE_REGISTRY}"
    fi

    if [ -n "${IMAGE_REPOSITORY}" ]; then
        OVERRIDES="$OVERRIDES --set image.repository=${IMAGE_REPOSITORY}"
    fi

    if [ -n "${IMAGE_TAG}" ]; then
        OVERRIDES="$OVERRIDES --set image.tag=${IMAGE_TAG}"
    fi

    if [ -n "${MEMORY_REQUEST}" ]; then
        OVERRIDES="$OVERRIDES --set resources.requests.memory=${MEMORY_REQUEST}"
    fi

    if [ -n "${CPU_REQUEST}" ]; then
        OVERRIDES="$OVERRIDES --set resources.requests.cpu=${CPU_REQUEST}"
    fi

    if [ -n "${MEMORY_LIMIT}" ]; then
        OVERRIDES="$OVERRIDES --set resources.limits.memory=${MEMORY_LIMIT}"
    fi

    if [ -n "${CPU_LIMIT}" ]; then
        OVERRIDES="$OVERRIDES --set resources.limits.cpu=${CPU_LIMIT}"
    fi

    if [ -n "${SERVICE_PORT}" ]; then
        OVERRIDES="$OVERRIDES --set service.port=${SERVICE_PORT}"
    fi

    # ConfigMap enabled
    # NOTA: ConfigMap ahora se gestiona desde app/application.yaml
    # Solo se habilita/deshabilita desde Library Groups
    if [ -n "${CONFIGMAP_ENABLED}" ]; then
        OVERRIDES="$OVERRIDES --set configMap.enabled=${CONFIGMAP_ENABLED}"
    fi

    # Ingress configuration
    if [ -n "${INGRESS_ENABLED}" ]; then
        OVERRIDES="$OVERRIDES --set ingress.enabled=${INGRESS_ENABLED}"
    fi

    if [ -n "${INGRESS_CLASS_NAME}" ]; then
        OVERRIDES="$OVERRIDES --set ingress.className=${INGRESS_CLASS_NAME}"
    fi

    if [ -n "${INGRESS_HOST}" ]; then
        OVERRIDES="$OVERRIDES --set ingress.rules[0].host=${INGRESS_HOST}"
    fi

    if [ -n "${INGRESS_PATH}" ]; then
        OVERRIDES="$OVERRIDES --set ingress.rules[0].paths[0].path=${INGRESS_PATH}"
    fi

    # Ingress rewrite-target (optional - para reescribir el path antes de enviar al backend)
    if [ -n "${INGRESS_REWRITE_TARGET}" ]; then
        OVERRIDES="$OVERRIDES --set ingress.annotations.rewriteTarget=${INGRESS_REWRITE_TARGET}"
    fi

    # Ingress TLS configuration
    if [ -n "${INGRESS_TLS_ENABLED}" ]; then
        OVERRIDES="$OVERRIDES --set ingress.tls.enabled=${INGRESS_TLS_ENABLED}"
    fi

    if [ -n "${INGRESS_TLS_HOSTS}" ]; then
        OVERRIDES="$OVERRIDES --set ingress.tls.hosts[0]=${INGRESS_TLS_HOSTS}"
    fi

    if [ -n "${INGRESS_TLS_SECRET_NAME}" ]; then
        OVERRIDES="$OVERRIDES --set ingress.tls.secretName=${INGRESS_TLS_SECRET_NAME}"
    fi

    # Ingress mTLS configuration
    if [ -n "${INGRESS_MTLS_ENABLED}" ]; then
        OVERRIDES="$OVERRIDES --set ingress.mtls.enabled=${INGRESS_MTLS_ENABLED}"
    fi

    if [ -n "${INGRESS_MTLS_SECRET_NAME}" ]; then
        OVERRIDES="$OVERRIDES --set ingress.mtls.secretName=${INGRESS_MTLS_SECRET_NAME}"
    fi

    if [ -n "${INGRESS_MTLS_VERIFY_CLIENT}" ]; then
        OVERRIDES="$OVERRIDES --set ingress.mtls.verifyClient=${INGRESS_MTLS_VERIFY_CLIENT}"
    fi

    # HPA (Horizontal Pod Autoscaler) configuration
    if [ -n "${HPA_ENABLED}" ]; then
        OVERRIDES="$OVERRIDES --set hpa.enabled=${HPA_ENABLED}"
    fi

    if [ -n "${HPA_MIN_REPLICAS}" ]; then
        OVERRIDES="$OVERRIDES --set hpa.minReplicas=${HPA_MIN_REPLICAS}"
    fi

    if [ -n "${HPA_MAX_REPLICAS}" ]; then
        OVERRIDES="$OVERRIDES --set hpa.maxReplicas=${HPA_MAX_REPLICAS}"
    fi

    if [ -n "${HPA_TARGET_CPU}" ]; then
        OVERRIDES="$OVERRIDES --set hpa.targetCPUUtilizationPercentage=${HPA_TARGET_CPU}"
    fi

    if [ -n "${HPA_TARGET_MEMORY}" ]; then
        OVERRIDES="$OVERRIDES --set hpa.targetMemoryUtilizationPercentage=${HPA_TARGET_MEMORY}"
    fi

    # ServiceAccount configuration
    if [ -n "${SERVICEACCOUNT_ENABLED}" ]; then
        OVERRIDES="$OVERRIDES --set serviceAccount.enabled=${SERVICEACCOUNT_ENABLED}"
    fi

    if [ -n "${SERVICEACCOUNT_IRSA_ROLE_ARN}" ]; then
        OVERRIDES="$OVERRIDES --set serviceAccount.annotations.irsaRoleArn=${SERVICEACCOUNT_IRSA_ROLE_ARN}"
    fi

    if [ -n "${SERVICEACCOUNT_AZURE_CLIENT_ID}" ]; then
        OVERRIDES="$OVERRIDES --set serviceAccount.annotations.azureClientId=${SERVICEACCOUNT_AZURE_CLIENT_ID}"
    fi

    # PDB (Pod Disruption Budget) configuration
    if [ -n "${PDB_ENABLED}" ]; then
        OVERRIDES="$OVERRIDES --set pdb.enabled=${PDB_ENABLED}"
    fi

    if [ -n "${PDB_MIN_AVAILABLE}" ]; then
        OVERRIDES="$OVERRIDES --set pdb.minAvailable=${PDB_MIN_AVAILABLE}"
    fi

    if [ -n "${PDB_MAX_UNAVAILABLE}" ]; then
        OVERRIDES="$OVERRIDES --set pdb.maxUnavailable=${PDB_MAX_UNAVAILABLE}"
    fi

    echo "${OVERRIDES}"
}

# Función para mostrar configuración
show_config() {
    print_header "CONFIGURACIÓN DEL DEPLOYMENT"

    # Valores base desde values.yaml
    local BASE_APP_NAME=$(grep "^appName:" "${CHART_PATH}/values.yaml" | awk '{print $2}')
    local BASE_NAMESPACE=$(grep "^namespace:" "${CHART_PATH}/values.yaml" | awk '{print $2}')
    local BASE_IMAGE=$(grep "repository:" "${CHART_PATH}/values.yaml" | head -2 | tail -1 | awk '{print $2}')
    local BASE_TAG=$(grep "tag:" "${CHART_PATH}/values.yaml" | head -1 | awk '{print $2}' | tr -d '"')
    local BASE_REPLICAS=$(grep "^replicaCount:" "${CHART_PATH}/values.yaml" | awk '{print $2}')

    echo -e "${CYAN}Ambiente:${NC} ${ENVIRONMENT:-local}"
    echo -e "${CYAN}Release Name:${NC} ${BASE_APP_NAME}"
    echo -e "${CYAN}Namespace:${NC} ${NAMESPACE:-$BASE_NAMESPACE} $([ -n "$NAMESPACE" ] && echo "(override)" || echo "(default)")"
    echo -e "${CYAN}Imagen:${NC} ${IMAGE_REGISTRY:-docker.io}/${IMAGE_REPOSITORY:-$BASE_IMAGE}:${IMAGE_TAG:-$BASE_TAG}"
    echo -e "${CYAN}Réplicas:${NC} ${REPLICA_COUNT:-$BASE_REPLICAS} $([ -n "$REPLICA_COUNT" ] && echo "(override)" || echo "(default)")"

    if [ -n "${MEMORY_REQUEST}" ] || [ -n "${CPU_REQUEST}" ]; then
        echo -e "${CYAN}Recursos (override):${NC}"
        echo -e "  Requests: Memory=${MEMORY_REQUEST:-128Mi} CPU=${CPU_REQUEST:-100m}"
        echo -e "  Limits:   Memory=${MEMORY_LIMIT:-256Mi} CPU=${CPU_LIMIT:-200m}"
    fi

    # ConfigMap info
    if [ -n "${CONFIGMAP_ENABLED}" ] && [ "${CONFIGMAP_ENABLED}" == "true" ]; then
        echo -e "${CYAN}ConfigMap:${NC} Habilitado"
        echo -e "  Configuración desde: ${CYAN}app/application.yaml${NC}"
        echo -e "  Montado en: ${CYAN}/app/config/application.yaml${NC}"
        echo -e "  Tipo: ${CYAN}Archivo (Spring Boot config)${NC}"
    else
        echo -e "${CYAN}ConfigMap:${NC} Deshabilitado"
    fi
    echo ""
}

# Función para verificar/crear namespace
check_namespace() {
    # Usar namespace desde variable de entorno si existe, si no desde values.yaml
    local TARGET_NAMESPACE="${NAMESPACE:-$(grep "^namespace:" "${CHART_PATH}/values.yaml" | awk '{print $2}')}"

    print_info "Verificando namespace: ${TARGET_NAMESPACE}"

    if kubectl get namespace "${TARGET_NAMESPACE}" &> /dev/null; then
        print_success "Namespace '${TARGET_NAMESPACE}' existe"
    else
        print_warning "Namespace '${TARGET_NAMESPACE}' no existe"
        read -p "¿Deseas crear el namespace '${TARGET_NAMESPACE}'? (y/n): " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            kubectl create namespace "${TARGET_NAMESPACE}"
            print_success "Namespace '${TARGET_NAMESPACE}' creado"
        else
            print_error "Deployment cancelado. Crea el namespace manualmente"
            exit 1
        fi
    fi
}

# Función para desplegar/actualizar
deploy() {
    print_header "DESPLEGANDO APLICACIÓN"

    local APP_NAME=$(grep "^appName:" "${CHART_PATH}/values.yaml" | awk '{print $2}')
    local TARGET_NAMESPACE="${NAMESPACE:-$(grep "^namespace:" "${CHART_PATH}/values.yaml" | awk '{print $2}')}"

    # Construir argumentos de override
    local HELM_OVERRIDES=$(build_helm_overrides)

    # Mostrar comando
    print_info "Ejecutando Helm Deploy..."
    echo -e "${BLUE}helm upgrade --install ${APP_NAME} ${CHART_PATH}${NC}"
    echo -e "${BLUE}  -f ${CHART_PATH}/values.yaml${NC}"
    echo -e "${BLUE}  -f ${SCRIPT_DIR}/app/application.yaml  ${CYAN}(Desarrollador)${NC}"
    echo -e "${BLUE}  -n ${TARGET_NAMESPACE}${NC}"
    if [ -n "${HELM_OVERRIDES}" ]; then
        echo -e "${BLUE}  ${HELM_OVERRIDES}${NC}"
    fi
    echo ""

    # Ejecutar helm upgrade --install
    # NOTA: Se incluye -f app/application.yaml para configuración del desarrollador
    if helm upgrade --install "${APP_NAME}" "${CHART_PATH}" \
        -f "${CHART_PATH}/values.yaml" \
        -f "${SCRIPT_DIR}/app/application.yaml" \
        -n "${TARGET_NAMESPACE}" \
        ${HELM_OVERRIDES} \
        --wait; then

        print_success "Deployment exitoso!"
        echo ""

        print_info "Esperando a que los pods estén listos..."
        sleep 3

        # Mostrar estado
        show_status

    else
        print_error "Falló el deployment"
        exit 1
    fi
}

# Función para mostrar el estado
show_status() {
    print_header "ESTADO DEL DEPLOYMENT"

    local APP_NAME=$(grep "^appName:" "${CHART_PATH}/values.yaml" | awk '{print $2}')
    local TARGET_NAMESPACE="${NAMESPACE:-$(grep "^namespace:" "${CHART_PATH}/values.yaml" | awk '{print $2}')}"

    # Verificar si el release existe
    if ! helm list -n "${TARGET_NAMESPACE}" | grep -q "${APP_NAME}"; then
        print_warning "No se encontró el release '${APP_NAME}' en el namespace '${TARGET_NAMESPACE}'"
        print_info "Usa './deployment.sh deploy --env <ambiente>' para desplegarlo"
        return
    fi

    # Helm release info
    print_info "Release de Helm:"
    helm list -n "${TARGET_NAMESPACE}" | grep "${APP_NAME}" || echo "No encontrado"
    echo ""

    # Deployment
    print_info "Deployment:"
    kubectl get deployment -n "${TARGET_NAMESPACE}" -l app="${APP_NAME}" 2>/dev/null || echo "No encontrado"
    echo ""

    # Service
    print_info "Service:"
    kubectl get service -n "${TARGET_NAMESPACE}" -l app="${APP_NAME}" 2>/dev/null || echo "No encontrado"
    echo ""

    # Pods
    print_info "Pods:"
    kubectl get pods -n "${TARGET_NAMESPACE}" -l app="${APP_NAME}" 2>/dev/null || echo "No encontrado"
    echo ""

    # Eventos recientes
    print_info "Eventos recientes:"
    kubectl get events -n "${TARGET_NAMESPACE}" --sort-by='.lastTimestamp' 2>/dev/null | tail -5
    echo ""

    # Comandos útiles
    print_header "COMANDOS ÚTILES"
    echo -e "${CYAN}Ver logs:${NC}"
    echo "  kubectl logs -f deployment/${APP_NAME}-deployment -n ${TARGET_NAMESPACE}"
    echo ""
    echo -e "${CYAN}Describir deployment:${NC}"
    echo "  kubectl describe deployment ${APP_NAME}-deployment -n ${TARGET_NAMESPACE}"
    echo ""
    echo -e "${CYAN}Port-forward (testing local):${NC}"
    echo "  kubectl port-forward service/${APP_NAME}-service 8080:80 -n ${TARGET_NAMESPACE}"
    echo ""
    echo -e "${CYAN}Ver todos los recursos:${NC}"
    echo "  kubectl get all -n ${TARGET_NAMESPACE} -l app=${APP_NAME}"
    echo ""
}

# Función para ver logs
show_logs() {
    local APP_NAME=$(grep "^appName:" "${CHART_PATH}/values.yaml" | awk '{print $2}')
    local TARGET_NAMESPACE="${NAMESPACE:-$(grep "^namespace:" "${CHART_PATH}/values.yaml" | awk '{print $2}')}"

    print_header "LOGS DE LA APLICACIÓN"
    print_info "Mostrando logs de deployment/${APP_NAME}-deployment en namespace ${TARGET_NAMESPACE}"
    print_info "Presiona Ctrl+C para salir"
    echo ""

    kubectl logs -f deployment/"${APP_NAME}-deployment" -n "${TARGET_NAMESPACE}"
}

# Función para eliminar el deployment
delete() {
    local APP_NAME=$(grep "^appName:" "${CHART_PATH}/values.yaml" | awk '{print $2}')
    local TARGET_NAMESPACE="${NAMESPACE:-$(grep "^namespace:" "${CHART_PATH}/values.yaml" | awk '{print $2}')}"

    print_header "ELIMINAR DEPLOYMENT"
    print_warning "Estás a punto de ELIMINAR el release '${APP_NAME}' del namespace '${TARGET_NAMESPACE}'"

    read -p "¿Estás seguro? (y/n): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        print_info "Eliminando release..."

        if helm uninstall "${APP_NAME}" -n "${TARGET_NAMESPACE}"; then
            print_success "Release eliminado exitosamente"

            # Verificar que los recursos fueron eliminados
            print_info "Verificando eliminación de recursos..."
            sleep 2

            local REMAINING_PODS=$(kubectl get pods -n "${TARGET_NAMESPACE}" -l app="${APP_NAME}" --no-headers 2>/dev/null | wc -l)
            if [ "${REMAINING_PODS}" -eq 0 ]; then
                print_success "Todos los recursos fueron eliminados"
            else
                print_warning "Aún hay ${REMAINING_PODS} pods terminando..."
                print_info "Puedes verificar con: kubectl get pods -n ${TARGET_NAMESPACE} -l app=${APP_NAME}"
            fi
        else
            print_error "Falló la eliminación del release"
            exit 1
        fi
    else
        print_info "Eliminación cancelada"
    fi
}

# Función para mostrar ayuda
show_help() {
    cat << EOF
Uso: ./deployment.sh [COMANDO] [OPCIONES]

🎯 Simula el flujo de Azure DevOps con Library Groups usando archivos de ambiente

Comandos disponibles:
  deploy    - Despliega o actualiza la aplicación en Kubernetes
  status    - Muestra el estado del deployment
  logs      - Muestra los logs de la aplicación en tiempo real
  delete    - Elimina el deployment de Kubernetes
  help      - Muestra esta ayuda

Opciones:
  --env <ambiente>    Especifica el ambiente (dev, staging, prod)
                      Carga el archivo .env.<ambiente>
                      Simula Azure DevOps Library Groups

Ejemplos:

  # Deployment con valores por defecto (values.yaml)
  ./deployment.sh deploy

  # Deployment en ambiente DEV (usa .env.dev)
  ./deployment.sh deploy --env dev

  # Deployment en ambiente PROD (usa .env.prod)
  ./deployment.sh deploy --env prod

  # Ver estado (detecta namespace automáticamente)
  ./deployment.sh status

  # Ver estado de ambiente específico
  ./deployment.sh status --env prod

  # Ver logs
  ./deployment.sh logs --env dev

  # Eliminar deployment
  ./deployment.sh delete --env dev

Archivos de Ambiente:
  .env.dev       - Variables para desarrollo
  .env.staging   - Variables para staging
  .env.prod      - Variables para producción

  Las variables sobrescriben los valores de k8s/values.yaml
  Similar a Azure DevOps Library Groups

Variables soportadas en archivos .env:
  NAMESPACE          - Namespace de Kubernetes
  REPLICA_COUNT      - Número de réplicas
  IMAGE_REGISTRY     - Registry de Docker
  IMAGE_REPOSITORY   - Repositorio de la imagen
  IMAGE_TAG          - Tag de la imagen
  MEMORY_REQUEST     - Memoria request
  CPU_REQUEST        - CPU request
  MEMORY_LIMIT       - Memoria limit
  CPU_LIMIT          - CPU limit
  SERVICE_PORT       - Puerto del servicio

  ConfigMap (configuración de aplicación):
  CONFIGMAP_ENABLED        - Habilitar/deshabilitar ConfigMap (true/false)
                             Nota: La configuración se gestiona desde app/application.yaml
                             El desarrollador mantiene ese archivo

EOF
}

##############################################################################
# MAIN
##############################################################################

main() {
    show_banner

    # Si no hay argumentos, mostrar ayuda
    if [ $# -eq 0 ]; then
        show_help
        exit 0
    fi

    # Procesar argumentos
    COMMAND=$1
    shift

    # Procesar opciones
    while [[ $# -gt 0 ]]; do
        case $1 in
            --env)
                ENVIRONMENT="$2"
                ENV_FILE="${SCRIPT_DIR}/.env.${ENVIRONMENT}"
                shift 2
                ;;
            *)
                print_error "Opción desconocida: $1"
                show_help
                exit 1
                ;;
        esac
    done

    # Ejecutar comando
    case "${COMMAND}" in
        deploy)
            check_prerequisites
            load_env_vars
            show_config
            check_namespace
            deploy
            ;;
        status)
            check_prerequisites
            load_env_vars
            show_status
            ;;
        logs)
            check_prerequisites
            load_env_vars
            show_logs
            ;;
        delete)
            check_prerequisites
            load_env_vars
            delete
            ;;
        help|--help|-h)
            show_help
            ;;
        *)
            print_error "Comando desconocido: ${COMMAND}"
            echo ""
            show_help
            exit 1
            ;;
    esac
}

# Ejecutar main
main "$@"
