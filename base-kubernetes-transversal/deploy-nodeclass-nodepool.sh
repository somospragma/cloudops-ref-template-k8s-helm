#!/bin/bash

set -e

# Función para ofuscar Account ID
mask_account_id() {
    sed "s/$AWS_ACCOUNT_ID/***masked***/g"
}

# Cargar variables
if [ ! -f "config.env" ]; then
    echo "❌ Archivo config.env no encontrado"
    exit 1
fi
source config.env

echo "🚀 Desplegando NodeClass y NodePool..."

# Configurar contexto del cluster automáticamente
echo "🔧 Configurando contexto del cluster $CLUSTER_NAME..."
aws eks update-kubeconfig --region $AWS_REGION --name $CLUSTER_NAME 2>&1 | mask_account_id
if [ $? -ne 0 ]; then
    echo "❌ Error configurando contexto del cluster"
    exit 1
fi

# Generar YAML dinámicamente con variables
echo "📄 Generando YAML con variables del config.env..."

# Crear archivo YAML temporal con variables
cat > nodeclass-nodepool-generated.yaml << 'EOF'
apiVersion: eks.amazonaws.com/v1
kind: NodeClass
metadata:
  name: NODECLASS_NAME_PLACEHOLDER
spec:
  role: "NODE_ROLE_NAME_PLACEHOLDER"
  subnetSelectorTerms:
    - tags:
        kubernetes.io/role/internal-elb: "1"
  securityGroupSelectorTerms:
    - tags:
        kubernetes.io/sg/nodes: "SECURITY_GROUP_TAG_VALUE_PLACEHOLDER"
  ephemeralStorage:
    size: "EPHEMERAL_STORAGE_SIZE_PLACEHOLDER"
  tags:
    Name: "INSTANCE_NAME_PLACEHOLDER"
    # Enterprise Tags
    cost-center: "TAG_COST_CENTER_PLACEHOLDER"
    tribu: "TAG_TRIBU_PLACEHOLDER"
    squad: "TAG_SQUAD_PLACEHOLDER"
    backup: "TAG_BACKUP_PLACEHOLDER"
    updated-date: "$(date +%Y-%m-%d)"
    country: "TAG_COUNTRY_PLACEHOLDER"
    application-name: "TAG_APPLICATION_NAME_PLACEHOLDER"
    company: "TAG_COMPANY_PLACEHOLDER"
    disaster-recovery: "TAG_DISASTER_RECOVERY_PLACEHOLDER"
    bia: "TAG_BIA_PLACEHOLDER"
    confidentiality: "TAG_CONFIDENTIALITY_PLACEHOLDER"
    integrity: "TAG_INTEGRITY_PLACEHOLDER"
    availability: "TAG_AVAILABILITY_PLACEHOLDER"
    pci: "TAG_PCI_PLACEHOLDER"
    environment: "TAG_ENVIRONMENT_PLACEHOLDER"
    map-migrated: "TAG_MAP_MIGRATED_PLACEHOLDER"
    tfmodule: "TAG_TFMODULE_PLACEHOLDER"
    schedule: "TAG_SCHEDULE_PLACEHOLDER"
    personal-data: "TAG_PERSONAL_DATA_PLACEHOLDER"
---
apiVersion: karpenter.sh/v1
kind: NodePool
metadata:
  name: NODEPOOL_NAME_PLACEHOLDER
spec:
  template:
    metadata:
      labels:
        billing-team: BILLING_TEAM_PLACEHOLDER
    spec:
      nodeClassRef:
        group: eks.amazonaws.com
        kind: NodeClass
        name: NODECLASS_NAME_PLACEHOLDER
      requirements:
        - key: "eks.amazonaws.com/instance-family"
          operator: In
          values: INSTANCE_FAMILIES_PLACEHOLDER
        - key: "topology.kubernetes.io/zone"
          operator: In
          values: AVAILABILITY_ZONES_PLACEHOLDER
        - key: "kubernetes.io/arch"
          operator: In
          values: ["NODE_ARCHITECTURE_PLACEHOLDER"]
        - key: "kubernetes.io/os"
          operator: In
          values: ["NODE_OS_PLACEHOLDER"]
        - key: "karpenter.sh/capacity-type"
          operator: In
          values: ["CAPACITY_TYPE_PLACEHOLDER"]
        - key: "CUSTOM_LABEL_KEY_PLACEHOLDER"
          operator: In
          values: ["CUSTOM_LABEL_VALUE_PLACEHOLDER"]
  disruption:
    consolidationPolicy: CONSOLIDATION_POLICY_PLACEHOLDER
    consolidateAfter: CONSOLIDATE_AFTER_PLACEHOLDER
    budgets:
    - nodes: "DISRUPTION_BUDGET_PLACEHOLDER"
  limits:
    cpu: "CPU_LIMIT_PLACEHOLDER"
    memory: MEMORY_LIMIT_PLACEHOLDER
EOF

# Reemplazar placeholders con valores reales

sed -i.bak "s/NODECLASS_NAME_PLACEHOLDER/$NODECLASS_NAME/g" nodeclass-nodepool-generated.yaml
sed -i.bak "s/NODE_ROLE_NAME_PLACEHOLDER/$NODE_ROLE_NAME/g" nodeclass-nodepool-generated.yaml
sed -i.bak "s/SECURITY_GROUP_TAG_VALUE_PLACEHOLDER/$SECURITY_GROUP_TAG_VALUE/g" nodeclass-nodepool-generated.yaml
sed -i.bak "s/EPHEMERAL_STORAGE_SIZE_PLACEHOLDER/$EPHEMERAL_STORAGE_SIZE/g" nodeclass-nodepool-generated.yaml
sed -i.bak "s/NODEPOOL_NAME_PLACEHOLDER/$NODEPOOL_NAME/g" nodeclass-nodepool-generated.yaml
sed -i.bak "s/BILLING_TEAM_PLACEHOLDER/$BILLING_TEAM/g" nodeclass-nodepool-generated.yaml
sed -i.bak "s/NODE_ARCHITECTURE_PLACEHOLDER/$NODE_ARCHITECTURE/g" nodeclass-nodepool-generated.yaml
sed -i.bak "s/NODE_OS_PLACEHOLDER/$NODE_OS/g" nodeclass-nodepool-generated.yaml
sed -i.bak "s/CPU_LIMIT_PLACEHOLDER/$CPU_LIMIT/g" nodeclass-nodepool-generated.yaml
sed -i.bak "s/MEMORY_LIMIT_PLACEHOLDER/$MEMORY_LIMIT/g" nodeclass-nodepool-generated.yaml
sed -i.bak "s/INSTANCE_NAME_PLACEHOLDER/$INSTANCE_NAME/g" nodeclass-nodepool-generated.yaml
sed -i.bak "s/CAPACITY_TYPE_PLACEHOLDER/$CAPACITY_TYPE/g" nodeclass-nodepool-generated.yaml
sed -i.bak "s/CUSTOM_LABEL_KEY_PLACEHOLDER/$CUSTOM_LABEL_KEY/g" nodeclass-nodepool-generated.yaml
sed -i.bak "s/CUSTOM_LABEL_VALUE_PLACEHOLDER/$CUSTOM_LABEL_VALUE/g" nodeclass-nodepool-generated.yaml
sed -i.bak "s/CONSOLIDATION_POLICY_PLACEHOLDER/$CONSOLIDATION_POLICY/g" nodeclass-nodepool-generated.yaml
sed -i.bak "s/CONSOLIDATE_AFTER_PLACEHOLDER/$CONSOLIDATE_AFTER/g" nodeclass-nodepool-generated.yaml
sed -i.bak "s/DISRUPTION_BUDGET_PLACEHOLDER/$DISRUPTION_BUDGET/g" nodeclass-nodepool-generated.yaml

# Reemplazar tags empresariales
sed -i.bak "s/TAG_COST_CENTER_PLACEHOLDER/$TAG_COST_CENTER/g" nodeclass-nodepool-generated.yaml
sed -i.bak "s/TAG_TRIBU_PLACEHOLDER/$TAG_TRIBU/g" nodeclass-nodepool-generated.yaml
sed -i.bak "s/TAG_SQUAD_PLACEHOLDER/$TAG_SQUAD/g" nodeclass-nodepool-generated.yaml
sed -i.bak "s/TAG_BACKUP_PLACEHOLDER/$TAG_BACKUP/g" nodeclass-nodepool-generated.yaml
sed -i.bak "s/TAG_COUNTRY_PLACEHOLDER/$TAG_COUNTRY/g" nodeclass-nodepool-generated.yaml
sed -i.bak "s/TAG_APPLICATION_NAME_PLACEHOLDER/$TAG_APPLICATION_NAME/g" nodeclass-nodepool-generated.yaml
sed -i.bak "s/TAG_COMPANY_PLACEHOLDER/$TAG_COMPANY/g" nodeclass-nodepool-generated.yaml
sed -i.bak "s/TAG_DISASTER_RECOVERY_PLACEHOLDER/$TAG_DISASTER_RECOVERY/g" nodeclass-nodepool-generated.yaml
sed -i.bak "s/TAG_BIA_PLACEHOLDER/$TAG_BIA/g" nodeclass-nodepool-generated.yaml
sed -i.bak "s/TAG_CONFIDENTIALITY_PLACEHOLDER/$TAG_CONFIDENTIALITY/g" nodeclass-nodepool-generated.yaml
sed -i.bak "s/TAG_INTEGRITY_PLACEHOLDER/$TAG_INTEGRITY/g" nodeclass-nodepool-generated.yaml
sed -i.bak "s/TAG_AVAILABILITY_PLACEHOLDER/$TAG_AVAILABILITY/g" nodeclass-nodepool-generated.yaml
sed -i.bak "s/TAG_PCI_PLACEHOLDER/$TAG_PCI/g" nodeclass-nodepool-generated.yaml
sed -i.bak "s/TAG_ENVIRONMENT_PLACEHOLDER/$TAG_ENVIRONMENT/g" nodeclass-nodepool-generated.yaml
sed -i.bak "s/TAG_MAP_MIGRATED_PLACEHOLDER/$TAG_MAP_MIGRATED/g" nodeclass-nodepool-generated.yaml
sed -i.bak "s/TAG_TFMODULE_PLACEHOLDER/$TAG_TFMODULE/g" nodeclass-nodepool-generated.yaml
sed -i.bak "s/TAG_SCHEDULE_PLACEHOLDER/$TAG_SCHEDULE/g" nodeclass-nodepool-generated.yaml
sed -i.bak "s/TAG_PERSONAL_DATA_PLACEHOLDER/$TAG_PERSONAL_DATA/g" nodeclass-nodepool-generated.yaml

# Convertir listas separadas por comas a formato JSON array
FAMILIES_JSON="["
IFS=',' read -ra FAMILIES <<< "$INSTANCE_FAMILIES"
for i in "${!FAMILIES[@]}"; do
    if [ $i -gt 0 ]; then FAMILIES_JSON="$FAMILIES_JSON, "; fi
    FAMILIES_JSON="$FAMILIES_JSON\"${FAMILIES[i]}\""
done
FAMILIES_JSON="$FAMILIES_JSON]"

ZONES_JSON="["
IFS=',' read -ra ZONES <<< "$AVAILABILITY_ZONES"
for i in "${!ZONES[@]}"; do
    if [ $i -gt 0 ]; then ZONES_JSON="$ZONES_JSON, "; fi
    ZONES_JSON="$ZONES_JSON\"${ZONES[i]}\""
done
ZONES_JSON="$ZONES_JSON]"

sed -i.bak "s|INSTANCE_FAMILIES_PLACEHOLDER|$FAMILIES_JSON|g" nodeclass-nodepool-generated.yaml
sed -i.bak "s|AVAILABILITY_ZONES_PLACEHOLDER|$ZONES_JSON|g" nodeclass-nodepool-generated.yaml

# Limpiar archivos backup
rm -f nodeclass-nodepool-generated.yaml.bak

echo "📄 Aplicando YAML generado..."

# Aplicar el YAML generado
kubectl apply -f nodeclass-nodepool-generated.yaml | mask_account_id

echo "⏳ Esperando a que los recursos estén listos..."

# Verificar NodeClass
if kubectl get nodeclass $NODECLASS_NAME 2>/dev/null >/dev/null; then
    echo "   ✅ NodeClass creado: $NODECLASS_NAME"
else
    echo "   ⚠️ NodeClass no encontrado: $NODECLASS_NAME"
fi

# Verificar NodePool
if kubectl get nodepool $NODEPOOL_NAME 2>/dev/null >/dev/null; then
    echo "   ✅ NodePool creado: $NODEPOOL_NAME"
    
    # Esperar a que el NodePool esté listo
    echo "   ⏳ Esperando a que NodePool esté listo..."
    kubectl wait --for=condition=Ready --timeout=600s nodepool/$NODEPOOL_NAME 2>/dev/null | mask_account_id || echo "   ⚠️ Timeout esperando NodePool (esto es normal, puede tomar varios minutos)"
else
    echo "   ⚠️ NodePool no encontrado: $NODEPOOL_NAME"
fi

echo "✅ NodeClass y NodePool aplicados correctamente"
echo ""
echo "🔍 Estado de los recursos:"
echo "NodeClass:"
kubectl get nodeclass $NODECLASS_NAME 2>/dev/null | mask_account_id || echo "   No encontrado"
echo ""
echo "NodePool:"
kubectl get nodepool $NODEPOOL_NAME 2>/dev/null | mask_account_id || echo "   No encontrado"
echo ""
echo "📋 Para verificar nodos:"
echo "kubectl get nodes"

# Limpiar archivo temporal
rm -f nodeclass-nodepool-generated.yaml nodeclass-nodepool-generated.yaml.bak
