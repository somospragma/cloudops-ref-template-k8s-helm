# ALB Master - Shared Application Load Balancer

ALB Master centralizado para acoplar múltiples Ingress en un solo ALB físico, reduciendo costos y simplificando la gestión.

## 🚀 Uso Rápido

```bash
# Desplegar en desarrollo
./deployment.sh dev

# Desplegar en staging
./deployment.sh staging

# Desplegar en producción
./deployment.sh prod
```

## 📁 Estructura

```
k8s-alb-master/
├── templates/
│   ├── alb-master.yaml          # Ingress master
│   └── alb-default-backend.yaml # Backend por defecto
├── values.yaml                  # Configuración base
├── .env.dev                     # Variables desarrollo
├── .env.staging                 # Variables staging
├── .env.prod                    # Variables producción
├── deployment.sh                # Script de despliegue
└── README.md                    # Esta documentación
```

## ⚙️ Configuración por Ambiente

### Desarrollo (.env.dev)
- ALB interno (internal)
- Solo HTTP
- Sin SSL/mTLS/WAF
- 1 réplica backend

### Staging (.env.staging)
- ALB público (internet-facing)
- HTTP + HTTPS
- SSL habilitado
- WAF habilitado
- 2 réplicas backend

### Producción (.env.prod)
- ALB público (internet-facing)
- HTTP + HTTPS
- SSL + mTLS habilitado
- WAF habilitado
- 3 réplicas backend

## 🔗 Acoplar Otros Ingress

Para que otros Ingress usen este ALB master:

```yaml
# En tu values.yaml de la aplicación
ingress:
  enabled: true
  className: "alb"
  group:
    enabled: true
  annotations:
    awsGroupName: "dev-alb-group"  # Mismo que ALB_GROUP_NAME
  rules:
    - host: "api.example.com"
      paths:
        - path: "/api"
          pathType: "Prefix"
          servicePort: 80
```

## 🛡️ Características

- **TLS**: Certificados SSL automáticos con ACM
- **mTLS**: Autenticación mutua con Cognito/OIDC
- **WAF**: Protección con AWS WAF v2
- **Default Backend**: Manejo de tráfico no matcheado
- **Multi-ambiente**: Configuración específica por entorno

## 📊 Beneficios

- **Ahorro de costos**: 1 ALB para múltiples aplicaciones
- **Gestión centralizada**: Configuración SSL/WAF unificada
- **Escalabilidad**: Soporte para múltiples dominios y paths
- **Seguridad**: mTLS y WAF integrados