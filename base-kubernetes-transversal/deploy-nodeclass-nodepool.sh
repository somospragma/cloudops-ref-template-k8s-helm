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
aws eks update-kubeconfig --region $AWS_REGION --name $CLUSTER_NAME --profile $AWS_PROFILE 2>&1 | mask_account_id
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
        kubernetes.io/sg/nodes: "enabled"
  ephemeralStorage:
    size: "EPHEMERAL_STORAGE_SIZE_PLACEHOLDER"
  tags:
    Name: "INSTANCE_NAME_PLACEHOLDER"
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
        - key: "eks.amazonaws.com/instance-category"
          operator: In
          values: INSTANCE_CATEGORIES_PLACEHOLDER
        - key: "eks.amazonaws.com/instance-cpu"
          operator: In
          values: INSTANCE_CPUS_PLACEHOLDER
        - key: "topology.kubernetes.io/zone"
          operator: In
          values: AVAILABILITY_ZONES_PLACEHOLDER
        - key: "kubernetes.io/arch"
          operator: In
          values: ["NODE_ARCHITECTURE_PLACEHOLDER"]
  limits:
    cpu: "CPU_LIMIT_PLACEHOLDER"
    memory: MEMORY_LIMIT_PLACEHOLDER
EOF

# Reemplazar placeholders con valores reales

sed -i.bak "s/NODECLASS_NAME_PLACEHOLDER/$NODECLASS_NAME/g" nodeclass-nodepool-generated.yaml
sed -i.bak "s/NODE_ROLE_NAME_PLACEHOLDER/$NODE_ROLE_NAME/g" nodeclass-nodepool-generated.yaml
sed -i.bak "s/EPHEMERAL_STORAGE_SIZE_PLACEHOLDER/$EPHEMERAL_STORAGE_SIZE/g" nodeclass-nodepool-generated.yaml
sed -i.bak "s/NODEPOOL_NAME_PLACEHOLDER/$NODEPOOL_NAME/g" nodeclass-nodepool-generated.yaml
sed -i.bak "s/BILLING_TEAM_PLACEHOLDER/$BILLING_TEAM/g" nodeclass-nodepool-generated.yaml
sed -i.bak "s/NODE_ARCHITECTURE_PLACEHOLDER/$NODE_ARCHITECTURE/g" nodeclass-nodepool-generated.yaml
sed -i.bak "s/CPU_LIMIT_PLACEHOLDER/$CPU_LIMIT/g" nodeclass-nodepool-generated.yaml
sed -i.bak "s/MEMORY_LIMIT_PLACEHOLDER/$MEMORY_LIMIT/g" nodeclass-nodepool-generated.yaml
sed -i.bak "s/INSTANCE_NAME_PLACEHOLDER/$INSTANCE_NAME/g" nodeclass-nodepool-generated.yaml

# Convertir listas separadas por comas a formato JSON array
CATEGORIES_JSON="["
IFS=',' read -ra CATEGORIES <<< "$INSTANCE_CATEGORIES"
for i in "${!CATEGORIES[@]}"; do
    if [ $i -gt 0 ]; then CATEGORIES_JSON="$CATEGORIES_JSON, "; fi
    CATEGORIES_JSON="$CATEGORIES_JSON\"${CATEGORIES[i]}\""
done
CATEGORIES_JSON="$CATEGORIES_JSON]"

CPUS_JSON="["
IFS=',' read -ra CPUS <<< "$INSTANCE_CPUS"
for i in "${!CPUS[@]}"; do
    if [ $i -gt 0 ]; then CPUS_JSON="$CPUS_JSON, "; fi
    CPUS_JSON="$CPUS_JSON\"${CPUS[i]}\""
done
CPUS_JSON="$CPUS_JSON]"

ZONES_JSON="["
IFS=',' read -ra ZONES <<< "$AVAILABILITY_ZONES"
for i in "${!ZONES[@]}"; do
    if [ $i -gt 0 ]; then ZONES_JSON="$ZONES_JSON, "; fi
    ZONES_JSON="$ZONES_JSON\"${ZONES[i]}\""
done
ZONES_JSON="$ZONES_JSON]"

sed -i.bak "s|INSTANCE_CATEGORIES_PLACEHOLDER|$CATEGORIES_JSON|g" nodeclass-nodepool-generated.yaml
sed -i.bak "s|INSTANCE_CPUS_PLACEHOLDER|$CPUS_JSON|g" nodeclass-nodepool-generated.yaml
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
