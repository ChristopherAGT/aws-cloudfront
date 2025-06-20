#!/bin/bash

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

divider() {
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
}

# Validación de AWS CLI
divider
echo -e "${BOLD}${CYAN}🔍 Comprobando entorno...${RESET}"
divider

if ! command -v aws &> /dev/null; then
    echo -e "${RED}❌ AWS CLI no está instalado. Instalando...${RESET}"
    sudo apt update -qq && sudo apt install -y awscli
else
    echo -e "${GREEN}✔️ AWS CLI está instalado.${RESET}"
fi

# Verificar credenciales AWS configuradas o en variables de entorno
# Verificar si las credenciales están activas haciendo una llamada real
divider
echo -e "${BOLD}${CYAN}🔐 Verificando credenciales de AWS...${RESET}"
divider

if aws sts get-caller-identity --output json > /dev/null 2>&1; then
    echo -e "${GREEN}✔️ Credenciales de AWS válidas detectadas.${RESET}"
else
    echo -e "${YELLOW}⚠️ No se detectaron credenciales válidas. Ejecutando 'aws configure'...${RESET}"
    aws configure
    if aws sts get-caller-identity --output json > /dev/null 2>&1; then
        echo -e "${GREEN}✔️ Credenciales configuradas exitosamente.${RESET}"
    else
        echo -e "${RED}❌ No se pudieron configurar las credenciales. Abortando...${RESET}"
        exit 1
    fi
fi

# Verificar que jq esté instalado (lo usaremos para parsear JSON)
if ! command -v jq &> /dev/null; then
    echo -e "${YELLOW}⚠️ jq no está instalado. Instalando jq...${RESET}"
    sudo apt update -qq && sudo apt install -y jq
fi

# Ingreso del dominio con confirmación
divider
while true; do
    read -p $'\e[1;94m🌐 Ingrese el dominio de origen (ej: tu.dominio.com): \e[0m' ORIGIN_DOMAIN
    echo -e "${YELLOW}⚠️ Está a punto de usar el dominio: ${BOLD}${ORIGIN_DOMAIN}${RESET}"
    read -p $'\e[1;93m➡️ ¿Confirmar dominio? (s/n): \e[0m' CONFIRMAR
    case "${CONFIRMAR,,}" in
        s|si|y|yes) break ;;
        n|no) echo -e "${BLUE}🔁 Volvamos a intentarlo...${RESET}" ;;
        *) echo -e "${RED}❗ Por favor, responda con 's' o 'n'.${RESET}" ;;
    esac
done

# Descripción de la distribución
read -p $'\e[1;95m📝 Ingrese una descripción para la distribución (ej: Domain_1): \e[0m' DESCRIPTION

# Generar referencia única
REFERENCE="cf-ui-$(date +%s)"

# Crear configuración JSON
divider
echo -e "${BOLD}${CYAN}🛠️ Generando archivo de configuración...${RESET}"

cat > config_cloudfront.json <<EOF
{
  "CallerReference": "${REFERENCE}",
  "Comment": "${DESCRIPTION}",
  "Enabled": true,
  "PriceClass": "PriceClass_100",
  "HttpVersion": "http2",
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
          },
          "OriginReadTimeout": 30,
          "OriginKeepaliveTimeout": 5
        }
      }
    ]
  },
  "DefaultRootObject": "",
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
  }
}
EOF

echo -e "${GREEN}✔️ Archivo config_cloudfront.json creado.${RESET}"

# Crear distribución
divider
echo -e "${BOLD}${CYAN}🚀 Enviando configuración a CloudFront...${RESET}"

if aws cloudfront create-distribution --distribution-config file://config_cloudfront.json > salida_cloudfront.json 2>error.log; then
    DOMAIN=$(jq -r '.Distribution.DomainName' salida_cloudfront.json)
    echo -e "${GREEN}✅️ Distribución creada exitosamente.${RESET}"
    echo -e "${MAGENTA}🌍 URL de acceso: ${BOLD}https://${DOMAIN}${RESET}"
else
    echo -e "${RED}❌ Ocurrió un error al crear la distribución. Revise error.log para más detalles.${RESET}"
    cat error.log
fi

# Limpieza final
divider
echo -e "${BLUE}🧹 Limpiando archivos temporales...${RESET}"
rm -f config_cloudfront.json salida_cloudfront.json error.log

# Autodestrucción del script (opcional)
# echo -e "${RED}🧨 Eliminando el script: ${BOLD}$0${RESET}"
rm -- "$0"

# Créditos
divider
echo -e "${MAGENTA}🙌 Gracias por usar este asistente.${RESET}"
echo -e "${BOLD}${CYAN}🔧 Créditos a 👾 Leo Duarte${RESET}"
