#!/bin/bash

clear

# ╔════════════════════════════════════════════════════════════╗
# ║        🌐 ASISTENTE PARA CREAR UNA DISTRIBUCIÓN CLOUDFRONT            ║
# ╚════════════════════════════════════════════════════════════╝

# Colores
RED='\e[1;91m'
GREEN='\e[1;92m'
YELLOW='\e[1;93m'
BLUE='\e[1;94m'
MAGENTA='\e[1;95m'
CYAN='\e[1;96m'
BOLD='\e[1m'
RESET='\e[0m'

# Spinner
spinner() {
    local pid=$!
    local delay=0.15
    local spinstr='|/-\\'
    while kill -0 "$pid" 2>/dev/null; do
        printf " [%c]  " "$spinstr"
        spinstr=${spinstr#?}${spinstr%"$spinstr"}
        sleep $delay
        printf "\b\b\b\b\b\b"
    done
    wait "$pid" 2>/dev/null
}

divider() {
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
}

# Encabezado inicial
echo -e "${CYAN}"
echo "╔════════════════════════════════════════════════════════════╗"
echo "║        🌐 ASISTENTE PARA CREAR UNA DISTRIBUCIÓN CLOUDFRONT            ║"
echo "╚════════════════════════════════════════════════════════════╝"
echo -e "${RESET}"
sleep 1

echo -e "${MAGENTA}🧠 Preparando entorno para crear tu CDN...${RESET}"
sleep 1

divider
echo -e "${BOLD}${CYAN}🔧 Verificando entorno (CLI, jq, dependencias)...${RESET}"
divider

# Validar herramientas necesarias
check_command() {
    local cmd="$1"
    local pkg="$2"
    if ! command -v "$cmd" &> /dev/null; then
        echo -e "${YELLOW}⚙️ Instalando ${pkg}...${RESET}"
        (sudo apt-get update -qq && sudo apt-get install -y "$pkg") & spinner
    else
        echo -e "${GREEN}✔️ ${pkg} instalado.${RESET}"
    fi
}

check_command aws awscli
check_command jq jq

divider
echo -e "${BOLD}${CYAN}🔐 Autenticación con AWS${RESET}"
divider

# Verificar credenciales
if aws sts get-caller-identity &> /dev/null; then
    echo -e "${GREEN}🔓 Credenciales válidas detectadas.${RESET}"
else
    echo -e "${YELLOW}🔑 No se encontraron credenciales válidas. Ejecutando aws configure...${RESET}"
    aws configure
    if ! aws sts get-caller-identity &> /dev/null; then
        echo -e "${RED}❌ Credenciales inválidas. Abortando.${RESET}"
        exit 1
    fi
fi

# Paso: Ingreso de dominio
divider
echo -e "${BOLD}${CYAN}🌐 Configuración del dominio de origen${RESET}"
divider

while true; do
    read -p $'\e[1;94m🌍 Ingrese el dominio de origen (ej: midominio.com): \e[0m' ORIGIN_DOMAIN
    ORIGIN_DOMAIN=$(echo "$ORIGIN_DOMAIN" | tr '[:upper:]' '[:lower:]' | xargs)

    if [[ -z "$ORIGIN_DOMAIN" || "$ORIGIN_DOMAIN" =~ ^(https?://) ]]; then
        echo -e "${RED}❌ Dominio inválido. No incluya http(s)://${RESET}"
        continue
    fi

    if ! [[ "$ORIGIN_DOMAIN" =~ ^[a-z0-9.-]+$ ]]; then
        echo -e "${RED}❌ Dominio inválido. Solo letras, números, puntos y guiones.${RESET}"
        continue
    fi

    echo -e "${YELLOW}🔎 Dominio elegido: ${BOLD}${ORIGIN_DOMAIN}${RESET}"
    read -p $'\e[1;93m✅ ¿Confirmar? (s/n): \e[0m' CONFIRMAR
    [[ "${CONFIRMAR,,}" =~ ^(s|y|si|yes)$ ]] && break
done

# Generar nombre de referencia
REFERENCE="cf-ui-$(date +%s)"
ROOT_DOMAIN=$(echo "$ORIGIN_DOMAIN" | awk -F. '{n=split($0,a,"."); if(n>=2) print a[n-1]"."a[n]; else print $0}')

# Buscar certificado coincidente
divider
echo -e "${BOLD}${CYAN}🔒 Buscando certificado SSL para ${ROOT_DOMAIN}...${RESET}"
divider

CERT_ARN=$(aws acm list-certificates --region us-east-1 --output json | \
  jq -r --arg domain "$ROOT_DOMAIN" '.CertificateSummaryList[] | select(.DomainName | test($domain+"$")) | .CertificateArn' | head -n 1)

if [[ -n "$CERT_ARN" ]]; then
    echo -e "${GREEN}✔️ Certificado encontrado: ${CERT_ARN}${RESET}"
else
    echo -e "${RED}❌ No se encontró certificado para el dominio raíz. Abortando.${RESET}"
    exit 1
fi
divider

# Preguntar por descripción
read -p $'\e[1;95m📝 Descripción para la distribución [Default: Cloudfront_Domain1]: \e[0m' DESCRIPTION
DESCRIPTION="${DESCRIPTION:-Cloudfront_Domain_1}"

# Crear archivo de configuración JSON
divider
echo -e "${BOLD}${CYAN}🛠️ Generando configuración de distribución...${RESET}"

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
    "ViewerProtocolPolicy": "allow-all",
    "AllowedMethods": {
      "Quantity": 7,
      "Items": ["GET", "HEAD", "OPTIONS", "PUT", "POST", "PATCH", "DELETE"],
      "CachedMethods": {
        "Quantity": 2,
        "Items": ["GET", "HEAD"]
      }
    },
    "Compress": false,
    "CachePolicyId": "658327ea-f89d-4fab-a63d-7e88639e58f6",
    "OriginRequestPolicyId": "88a5eaf4-2fd4-4709-b370-b4c650ea3fcf"
  },
  "ViewerCertificate": {
    "ACMCertificateArn": "${CERT_ARN}",
    "SSLSupportMethod": "sni-only",
    "MinimumProtocolVersion": "TLSv1.2_2021"
  }
}
EOF

echo -e "${GREEN}✔️ Configuración guardada en config_cloudfront.json${RESET}"

# Crear la distribución
divider
echo -e "${BOLD}${CYAN}📡 Enviando configuración a CloudFront...${RESET}"

if aws cloudfront create-distribution --distribution-config file://config_cloudfront.json > salida_cloudfront.json 2>error.log; then
    DOMAIN=$(jq -r '.Distribution.DomainName' salida_cloudfront.json)
    echo -e "${GREEN}🎉 Distribución creada exitosamente.${RESET}"
else
    echo -e "${RED}💥 Error al crear la distribución.${RESET}"
    echo -e "${YELLOW}🪵 Detalles del error:${RESET}"
    cat error.log
    exit 1
fi

# Limpieza final
divider
echo -e "${BLUE}🧹 Limpiando archivos temporales...${RESET}"
rm -f config_cloudfront.json salida_cloudfront.json error.log

# Créditos
divider
echo -e "${GREEN}✅ Proceso finalizado correctamente.${RESET}"
divider
echo -e "${MAGENTA}🔗 URL de acceso: ${BOLD}https://${DOMAIN}${RESET}"
echo -e "${MAGENTA}🌍 Dominio configurado: ${BOLD}${ORIGIN_DOMAIN}${RESET}"
echo -e "${MAGENTA}📄 Descripción: ${DESCRIPTION}${RESET}"
echo -e "${MAGENTA}🔐 Certificado usado: ${CERT_ARN}${RESET}"
echo -e "${MAGENTA}🕒 Fecha: $(date)${RESET}"
divider
echo -e "${BOLD}${CYAN}🔧 Script creado por 👾 Christopher Ackerman${RESET}"
