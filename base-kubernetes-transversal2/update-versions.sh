#!/bin/bash

# Script para actualizar versiones de addons EKS
# Uso: ./update-versions.sh [lb-version] [ca-version]

LB_VERSION=${1:-"1.15.0"}
CA_VERSION=${2:-"9.37.0"}

echo "🔄 Actualizando versiones..."
echo "  - AWS Load Balancer Controller: $LB_VERSION"
echo "  - Cluster Autoscaler: $CA_VERSION"

# Actualizar Chart.yaml
sed -i.bak "s/version: [0-9]\+\.[0-9]\+\.[0-9]\+.*# aws-load-balancer-controller/version: $LB_VERSION # aws-load-balancer-controller/" Chart.yaml
sed -i.bak "s/version: [0-9]\+\.[0-9]\+\.[0-9]\+.*# cluster-autoscaler/version: $CA_VERSION # cluster-autoscaler/" Chart.yaml

# Si no hay comentarios, usar líneas específicas
sed -i.bak "/aws-load-balancer-controller/,/repository:/ s/version: [0-9]\+\.[0-9]\+\.[0-9]\+/version: $LB_VERSION/" Chart.yaml
sed -i.bak "/cluster-autoscaler/,/repository:/ s/version: [0-9]\+\.[0-9]\+\.[0-9]\+/version: $CA_VERSION/" Chart.yaml

# Actualizar dependencias
helm dependency update

echo "✅ Versiones actualizadas. Para aplicar:"
echo "   ./deployment.sh dev"
