#!/bin/bash

clear

# ╔════════════════════════════════════════════════════════════╗
# ║        🌐 ASISTENTE PARA CREAR UNA DISTRIBUCIÓN CLOUDFRONT ║
# ╚════════════════════════════════════════════════════════════╝

# Colores brillantes + negrita
RED='\e[1;91m'
GREEN='\e[1;92m'
YELLOW='\e[1;93m'
BLUE='\e[1;94m'
MAGENTA='\e[1;95m'
CYAN='\e[1;96m'
BOLD='\e[1m'
RESET='\e[0m'

# Spinner animado para tareas en segundo plano
spinner() {
    local pid=$1
    local delay=0.15
    local spinstr='|/-\\'
    while kill -0 $pid 2>/dev/null; do
        local temp=${spinstr#?}
        printf " [%c]  " "$spinstr"
        spinstr=$temp${spinstr%"$temp"}
        sleep $delay
        printf "\b\b\b\b\b\b"
    done
    wait $pid 2>/dev/null
}

divider() {
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
}

# Encabezado
echo -e "${CYAN}"
echo "╔════════════════════════════════════════════════════════════╗"
echo "║        🌐 ASISTENTE PARA CREAR UNA DISTRIBUCIÓN CLOUDFRONT ║"
echo "╚════════════════════════════════════════════════════════════╝"
echo -e "${RESET}"
sleep 0.5
echo -e "${MAGENTA}🧠 Preparando entorno para crear tu CDN...${RESET}"
sleep 1

# Validar AWS CLI
divider
echo -e "${BOLD}${CYAN}🔍 PASO 1: Comprobando entorno...${RESET}"
divider

if ! command -v aws &> /dev/null; then
    echo -e "${RED}❌ AWS CLI no está instalado. Instalando...${RESET}"
    (sudo apt update -qq && sudo apt install -y awscli) & 
    spinner $!
else
    echo -e "${GREEN}✔️ AWS CLI está instalado.${RESET}"
fi

# Verificar credenciales AWS
divider
echo -e "${BOLD}${CYAN}🔐 PASO 2: Verificando credenciales de AWS...${RESET}"
divider

if ! aws sts get-caller-identity --output json > /dev/null 2>&1; then
    echo -e "${YELLOW}⚠️ No se detectaron credenciales válidas. Ejecutando 'aws configure'...${RESET}"
    aws configure
    if ! aws sts get-caller-identity --output json > /dev/null 2>&1; then
        echo -e "${RED}❌ No se pudieron configurar las credenciales. Abortando...${RESET}"
        exit 1
    fi
else
    echo -e "${GREEN}🔐🔓 Credenciales de AWS válidas detectadas.${RESET}"
fi

# Verificar jq
if ! command -v jq &> /dev/null; then
    echo -e "${YELLOW}📦 Instalando jq...${RESET}"
    (sudo apt update -qq && sudo apt install -y jq) &
    spinner $!
fi

# Ingreso de dominio
divider
echo -e "${BOLD}${CYAN}🌐 PASO 3: Ingreso del dominio de origen${RESET}"
divider
while true; do
    read -p $'\e[1;94m🌐 Ingrese el dominio de origen (ej: tu.dominio.com): \e[0m' ORIGIN_DOMAIN_RAW
    ORIGIN_DOMAIN=$(echo "$ORIGIN_DOMAIN_RAW" | tr '[:upper:]' '[:lower:]' | xargs)

    if [[ -z "$ORIGIN_DOMAIN" || "$ORIGIN_DOMAIN" =~ ^(http|https):// ]]; then
        echo -e "${RED}❌ Dominio inválido. No incluya http:// ni https:// y no lo deje vacío.${RESET}"
        continue
    fi

    if ! [[ "$ORIGIN_DOMAIN" =~ ^[a-z0-9.-]+$ ]]; then
        echo -e "${RED}❌ Dominio inválido. Solo letras minúsculas, números, guiones y puntos.${RESET}"
        continue
    fi

    echo -e "${YELLOW}🔎 Usando el dominio: ${BOLD}${ORIGIN_DOMAIN}${RESET}"
    read -p $'\e[1;93m➡️ ¿Confirmar dominio? (s/n): \e[0m' CONFIRMAR
    [[ "${CONFIRMAR,,}" =~ ^(s|si|y|yes)$ ]] && break
done

ROOT_DOMAIN=$(echo "$ORIGIN_DOMAIN" | awk -F. '{print $(NF-1)"."$NF}')

# Buscar certificado en ACM que coincida
divider
echo -e "${BOLD}${CYAN}🔐 PASO 4: Buscando certificado SSL para ${ROOT_DOMAIN}...${RESET}"
divider

CERT_ARN=$(aws acm list-certificates --certificate-statuses ISSUED \
    --query "CertificateSummaryList[?DomainName=='${ROOT_DOMAIN}' || ends_with(DomainName, '.${ROOT_DOMAIN}')].CertificateArn" \
    --output text)

if [[ -z "$CERT_ARN" ]]; then
    echo -e "${RED}❌ No se encontró certificado válido para ${ROOT_DOMAIN}.${RESET}"
    exit 1
else
    echo -e "${GREEN}✔️ Certificado encontrado: ${BOLD}${CERT_ARN}${RESET}"
fi

# Descripción de la distribución
read -p $'\e[1;95m📝 Ingrese una descripción para la distribución [Default: Domain_1]: \e[0m' DESCRIPTION
DESCRIPTION=$(echo "$DESCRIPTION" | xargs)
[ -z "$DESCRIPTION" ] && DESCRIPTION="Domain_1"
REFERENCE="cf-ui-$(date +%s)"

# Crear archivo de configuración JSON
divider
echo -e "${BOLD}${CYAN}🛠️ PASO 5: Generando configuración...${RESET}"

cat > config_cloudfront.json <<EOF
{
  "CallerReference": "${REFERENCE}",
  "Comment": "${DESCRIPTION}",
  "Enabled": true,
  "PriceClass": "PriceClass_100",
  "HttpVersion": "http2",
  "IsIPV6Enabled": true,
  "Aliases": {
    "Quantity": 1,
    "Items": ["${ORIGIN_DOMAIN}"]
  },
  "Origins": {
    "Quantity": 1,
    "Items": [
      {
        "Id": "CustomOrigin",
        "DomainName": "${ORIGIN_DOMAIN}",
        "CustomOriginConfig": {
          "HTTPPort": 80,
          "HTTPSPort": 443,
          "OriginProtocolPolicy": "match-viewer",
          "OriginSslProtocols": {
            "Quantity": 1,
            "Items": ["TLSv1.2"]
          }
        }
      }
    ]
  },
  "DefaultCacheBehavior": {
    "TargetOriginId": "CustomOrigin",
    "ViewerProtocolPolicy": "redirect-to-https",
    "AllowedMethods": {
      "Quantity": 7,
      "Items": ["GET", "HEAD", "OPTIONS", "PUT", "POST", "PATCH", "DELETE"],
      "CachedMethods": {
        "Quantity": 2,
        "Items": ["GET", "HEAD"]
      }
    },
    "Compress": true,
    "CachePolicyId": "658327ea-f89d-4fab-a63d-7e88639e58f6",
    "OriginRequestPolicyId": "88a5eaf4-2fd4-4709-b370-b4c650ea3fcf"
  },
  "ViewerCertificate": {
    "ACMCertificateArn": "${CERT_ARN}",
    "SSLSupportMethod": "sni-only",
    "MinimumProtocolVersion": "TLSv1.2_2021",
    "Certificate": "${CERT_ARN}",
    "CertificateSource": "acm"
  }
}
EOF

echo -e "${GREEN}✔️ Archivo config_cloudfront.json generado.${RESET}"

# Crear la distribución
divider
echo -e "${BOLD}${CYAN}📡 PASO 6: Creando distribución en CloudFront...${RESET}"
if aws cloudfront create-distribution --distribution-config file://config_cloudfront.json > salida_cloudfront.json 2>error.log; then
    DOMAIN=$(jq -r '.Distribution.DomainName' salida_cloudfront.json)
    echo -e "${GREEN}\n🎯 ¡Distribución creada exitosamente!${RESET}"
    echo -e "${MAGENTA}🌍 URL de acceso: ${BOLD}https://${DOMAIN}${RESET}"
else
    echo -e "${RED}💥 Error al crear la distribución.${RESET}"
    echo -e "${YELLOW}📄 Ver detalles en: ${BOLD}error.log${RESET}"
    cat error.log
fi

# Limpieza
divider
echo -e "${BLUE}🗑️ Limpiando archivos temporales...${RESET}"
rm -f config_cloudfront.json salida_cloudfront.json error.log

# Eliminar script si deseas
# echo -e "${RED}🧨 Eliminando el script...${RESET}"
# rm -- "$0"

# Créditos
divider
echo -e "${GREEN}✅ Proceso completado.${RESET}"
echo -e "${MAGENTA}🌐 Dominio: ${BOLD}${ORIGIN_DOMAIN}${RESET}"
echo -e "${MAGENTA}🔐 Certificado: ${CERT_ARN}${RESET}"
echo -e "${BOLD}${CYAN}🔧 Créditos a 👾 Christopher Ackerman${RESET}"
