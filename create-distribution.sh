#!/bin/bash

clear

# ╔════════════════════════════════════════════════════════════╗
# ║        🌐 ASISTENTE PARA CREAR UNA DISTRIBUCIÓN CLOUDFRONT   ║
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

# Encabezado
echo -e "${CYAN}"
echo "╔════════════════════════════════════════════════════════════╗"
echo "║        🌐 ASISTENTE PARA CREAR UNA DISTRIBUCIÓN CLOUDFRONT   ║"
echo "╚════════════════════════════════════════════════════════════╝"
echo -e "${RESET}"
sleep 1

echo -e "${MAGENTA}🧠 Preparando entorno para crear tu CDN...${RESET}"
sleep 1

divider
echo -e "${BOLD}${CYAN}🔧 Verificando entorno (CLI, jq, dependencias)...${RESET}"
divider

# Validar herramientas
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

if aws sts get-caller-identity &> /dev/null; then
    echo -e "${GREEN}🔓 Credenciales válidas detectadas.${RESET}"
else
    echo -e "${YELLOW}🔑 No se encontraron credenciales válidas. Ejecutando aws configure...${RESET}"
    aws configure
    aws sts get-caller-identity &> /dev/null || exit 1
fi

# Dominio de origen
divider
echo -e "${BOLD}${CYAN}🌐 Configuración del dominio de origen${RESET}"
divider

while true; do
    read -p $'\e[1;94m🌍 Ingrese el dominio de origen (ej: midominio.com): \e[0m' ORIGIN_DOMAIN
    ORIGIN_DOMAIN=$(echo "$ORIGIN_DOMAIN" | tr '[:upper:]' '[:lower:]' | xargs)

    [[ -z "$ORIGIN_DOMAIN" || "$ORIGIN_DOMAIN" =~ ^https?:// ]] && echo -e "${RED}❌ Dominio inválido.${RESET}" && continue
    [[ ! "$ORIGIN_DOMAIN" =~ ^[a-z0-9.-]+$ ]] && echo -e "${RED}❌ Dominio inválido.${RESET}" && continue

    echo -e "${YELLOW}🔎 Dominio elegido: ${BOLD}${ORIGIN_DOMAIN}${RESET}"
    read -p $'\e[1;93m✅ ¿Confirmar? (s/n): \e[0m' CONFIRMAR
    [[ "${CONFIRMAR,,}" =~ ^(s|y|si|yes)$ ]] && break
done

# CNAME
divider
echo -e "${BOLD}${CYAN}🔗 Configuración del CNAME (Alias)${RESET}"
divider

while true; do
    read -p $'\e[1;93m❓ ¿Desea usar el mismo dominio como CNAME? (s/n): \e[0m' USE_SAME_CNAME

    if [[ "${USE_SAME_CNAME,,}" =~ ^(s|y|si|yes)$ ]]; then
        CNAME_DOMAIN="$ORIGIN_DOMAIN"
        break
    elif [[ "${USE_SAME_CNAME,,}" =~ ^(n|no)$ ]]; then
        read -p $'\e[1;94m🌍 Ingrese el subdominio para el CNAME (ej: cdn.midominio.com): \e[0m' CNAME_DOMAIN
        CNAME_DOMAIN=$(echo "$CNAME_DOMAIN" | tr '[:upper:]' '[:lower:]' | xargs)

        [[ -z "$CNAME_DOMAIN" || "$CNAME_DOMAIN" =~ ^https?:// ]] && echo -e "${RED}❌ Dominio inválido.${RESET}" && continue
        [[ ! "$CNAME_DOMAIN" =~ ^[a-z0-9.-]+$ ]] && echo -e "${RED}❌ Dominio inválido.${RESET}" && continue
        break
    else
        echo -e "${RED}❌ Opción inválida.${RESET}"
    fi
done

echo -e "${GREEN}✔️ CNAME configurado: ${BOLD}${CNAME_DOMAIN}${RESET}"

# Referencias
REFERENCE="cf-ui-$(date +%s)"
ROOT_DOMAIN=$(echo "$CNAME_DOMAIN" | awk -F. '{print $(NF-1)"."$NF}')

# Certificado
divider
echo -e "${BOLD}${CYAN}🔒 Buscando certificado SSL para ${ROOT_DOMAIN}...${RESET}"
divider

CERT_ARN=$(aws acm list-certificates --region us-east-1 --output json | \
jq -r --arg domain "$ROOT_DOMAIN" '.CertificateSummaryList[] | select(.DomainName | test($domain+"$")) | .CertificateArn' | head -n 1)

[[ -z "$CERT_ARN" ]] && echo -e "${RED}❌ No se encontró certificado.${RESET}" && exit 1
echo -e "${GREEN}✔️ Certificado encontrado.${RESET}"

divider
read -p $'\e[1;95m📝 Descripción [Default: Cloudfront_Domain_1]: \e[0m' DESCRIPTION
DESCRIPTION="${DESCRIPTION:-Cloudfront_Domain_1}"

# JSON
divider
echo -e "${BOLD}${CYAN}🛠️ Generando configuración...${RESET}"

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
    "Items": ["${CNAME_DOMAIN}"]
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
      "Items": ["GET","HEAD","OPTIONS","PUT","POST","PATCH","DELETE"],
      "CachedMethods": {
        "Quantity": 2,
        "Items": ["GET","HEAD"]
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

# Crear distribución
divider
echo -e "${BOLD}${CYAN}📡 Creando distribución CloudFront...${RESET}"

if aws cloudfront create-distribution --distribution-config file://config_cloudfront.json > salida_cloudfront.json 2>error.log; then
    DOMAIN=$(jq -r '.Distribution.DomainName' salida_cloudfront.json)
    echo -e "${GREEN}🎉 Distribución creada exitosamente.${RESET}"
else
    echo -e "${RED}💥 Error al crear la distribución.${RESET}"
    cat error.log
    exit 1
fi

# Limpieza
rm -f config_cloudfront.json salida_cloudfront.json error.log

divider
echo -e "${MAGENTA}🌍 Dominio de origen: ${BOLD}${ORIGIN_DOMAIN}${RESET}"
echo -e "${MAGENTA}🔗 CNAME configurado: ${BOLD}${CNAME_DOMAIN}${RESET}"
echo -e "${MAGENTA}🔗 URL CloudFront: ${BOLD}https://${DOMAIN}${RESET}"
echo -e "${MAGENTA}🔐 Certificado: ${CERT_ARN}${RESET}"
divider
echo -e "${BOLD}${CYAN}🔧 Script creado por 👾 Christopher Ackerman${RESET}"
