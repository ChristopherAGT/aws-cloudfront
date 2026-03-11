#!/bin/bash

clear

# ╔════════════════════════════════════════════════════════════╗
# ║        🌐 ASISTENTE PARA CREAR UNA DISTRIBUCIÓN CLOUDFRONT ║
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
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
}

# Encabezado
echo -e "${CYAN}"
echo "╔═════════════════════════════════════════════════════════════════════╗"
echo "║               🌐 ASISTENTE PARA CREAR UNA DISTRIBUCIÓN CLOUDFRONT  ║"
echo "╚═════════════════════════════════════════════════════════════════════╝"
echo -e "${RESET}"
sleep 1

echo -e "${MAGENTA}🧠 Preparando entorno para crear tu CDN...${RESET}"
sleep 1

divider
echo -e "${BOLD}${CYAN}🔧 Verificando entorno (CLI, jq, dependencias)...${RESET}"
divider

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

divider
read -p $'\e[1;93m❓ ¿Desea agregar un CNAME a la distribución? (s/n): \e[0m' USE_CNAME_INPUT

if [[ "${USE_CNAME_INPUT,,}" =~ ^(s|y|si|yes)$ ]]; then
    USE_CNAME=true
else
    USE_CNAME=false
fi

check_cname_exists() {
    local cname="$1"
    EXISTING_CNAME=$(aws cloudfront list-distributions --query "DistributionList.Items[?Aliases.Items[?contains(@, '${cname}')]].Aliases.Items" --output text)

    if [[ -n "$EXISTING_CNAME" ]]; then
        echo -e "${RED}❌ El CNAME ${cname} ya está asociado a otra distribución de CloudFront.${RESET}"
        return 1
    else
        return 0
    fi
}

if [ "$USE_CNAME" = true ]; then

divider
echo -e "${BOLD}${CYAN}🔗 Configuración del CNAME (Alias)${RESET}"
divider

while true; do
    read -p $'\e[1;93m❓ ¿Desea usar el mismo dominio como CNAME? (s/n): \e[0m' USE_SAME_CNAME

    if [[ "${USE_SAME_CNAME,,}" =~ ^(s|y|si|yes)$ ]]; then
        CNAME_DOMAIN="$ORIGIN_DOMAIN"
        check_cname_exists "$CNAME_DOMAIN" || continue
        break
    elif [[ "${USE_SAME_CNAME,,}" =~ ^(n|no)$ ]]; then
        read -p $'\e[1;94m🌍 Ingrese el subdominio para el CNAME (ej: cdn.midominio.com): \e[0m' CNAME_DOMAIN
        CNAME_DOMAIN=$(echo "$CNAME_DOMAIN" | tr '[:upper:]' '[:lower:]' | xargs)

        [[ -z "$CNAME_DOMAIN" || "$CNAME_DOMAIN" =~ ^https?:// ]] && echo -e "${RED}❌ Dominio inválido.${RESET}" && continue
        [[ ! "$CNAME_DOMAIN" =~ ^[a-z0-9.-]+$ ]] && echo -e "${RED}❌ Dominio inválido.${RESET}" && continue

        check_cname_exists "$CNAME_DOMAIN" || continue
        break
    else
        echo -e "${RED}❌ Opción inválida.${RESET}"
    fi
done

echo -e "${GREEN}✔️ CNAME configurado: ${BOLD}${CNAME_DOMAIN}${RESET}"

REFERENCE="cf-ui-$(date +%s)"
ROOT_DOMAIN=$(echo "$CNAME_DOMAIN" | awk -F. '{print $(NF-1)"."$NF}')

divider
echo -e "${BOLD}${CYAN}🔒 Buscando certificado SSL para ${ROOT_DOMAIN}...${RESET}"
divider

CERT_ARN=$(aws acm list-certificates --region us-east-1 --output json | \
jq -r --arg domain "$ROOT_DOMAIN" '.CertificateSummaryList[] | select(.DomainName | test($domain+"$")) | .CertificateArn' | head -n 1)

[[ -z "$CERT_ARN" ]] && echo -e "${RED}❌ No se encontró certificado.${RESET}" && exit 1
echo -e "${GREEN}✔️ Certificado encontrado.${RESET}"

else
REFERENCE="cf-ui-$(date +%s)"
fi

divider
read -p $'\e[1;95m📝 Descripción [Default: Cloudfront_Domain_1]: \e[0m' DESCRIPTION
DESCRIPTION="${DESCRIPTION:-Cloudfront_Domain_1}"

divider
echo -e "${BOLD}${CYAN}🛠️ Generando configuración...${RESET}"

if [ "$USE_CNAME" = true ]; then

cat > config_cloudfront.json <<EOF
{
  "CallerReference": "${REFERENCE}",
  "Comment": "${DESCRIPTION}",
  "Enabled": true,
  "PriceClass": "PriceClass_100",
  "HttpVersion": "http1.1",
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
    "CachePolicyId": "4135ea2d-6df8-44a3-9df3-4b5a84be39ad",
    "OriginRequestPolicyId": "216adef6-5c7f-47e4-b989-5492eafa07d3"
  },
  "ViewerCertificate": {
    "ACMCertificateArn": "${CERT_ARN}",
    "SSLSupportMethod": "sni-only",
    "MinimumProtocolVersion": "TLSv1.2_2021"
  }
}
EOF

else

cat > config_cloudfront.json <<EOF
{
  "CallerReference": "${REFERENCE}",
  "Comment": "${DESCRIPTION}",
  "Enabled": true,
  "PriceClass": "PriceClass_100",
  "HttpVersion": "http1.1",
  "IsIPV6Enabled": true,
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
    "CachePolicyId": "4135ea2d-6df8-44a3-9df3-4b5a84be39ad",
    "OriginRequestPolicyId": "216adef6-5c7f-47e4-b989-5492eafa07d3"
  }
}
EOF

fi

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

rm -f config_cloudfront.json salida_cloudfront.json error.log

divider
echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
echo -e "${MAGENTA} █████╗ ██╗    ██╗███████╗${RESET}"
echo -e "${MAGENTA}██╔══██╗██║    ██║██╔════╝${RESET}"
echo -e "${MAGENTA}███████║██║ █╗ ██║███████╗${RESET}"
echo -e "${MAGENTA}██╔══██║██║███╗██║╚════██║${RESET}"
echo -e "${MAGENTA}██║  ██║╚███╔███╔╝███████║${RESET}"
echo -e "${MAGENTA}╚═╝  ╚═╝ ╚══╝╚══╝ ╚══════╝${RESET}"
echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"

echo -e "${MAGENTA}🌍 Dominio de origen: ${BOLD}${ORIGIN_DOMAIN}${RESET}"

if [ "$USE_CNAME" = true ]; then
echo -e "${MAGENTA}🔗 CNAME configurado: ${BOLD}${CNAME_DOMAIN}${RESET}"
fi

echo -e "${MAGENTA}🔗 URL CloudFront: ${BOLD}https://${DOMAIN}${RESET}"

if [ "$USE_CNAME" = true ]; then
echo -e "${MAGENTA}🔐 Certificado: ${CERT_ARN}${RESET}"
fi

divider
echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
echo -e "${BOLD}${CYAN}🔧 Script creado por 👾 Christopher Ackerman${RESET}"
divider
