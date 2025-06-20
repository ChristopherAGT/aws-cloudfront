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

# Spinner animado para tareas largas
spinner() {
    local pid=$!
    local delay=0.15
    local spinstr='|/-\\'
    while [ -d /proc/$pid ]; do
        local temp=${spinstr#?}
        printf " [%c]  " "$spinstr"
        local spinstr=$temp${spinstr%"$temp"}
        sleep $delay
        printf "\b\b\b\b\b\b"
    done
    wait $pid 2>/dev/null
}

divider() {
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
}

# Encabezado bonito
echo -e "${CYAN}"
echo "╔════════════════════════════════════════════════════════════╗"
echo "║        🌐 ASISTENTE PARA CREAR UNA DISTRIBUCIÓN CLOUDFRONT ║"
echo "╚════════════════════════════════════════════════════════════╝"
echo -e "${RESET}"
sleep 0.5
echo -e "${MAGENTA}🧠 Preparando entorno para crear tu CDN...${RESET}"
sleep 1

# PASO 1: Validación de AWS CLI
divider
echo -e "${BOLD}${CYAN}🔍 PASO 1: Comprobando entorno...${RESET}"
divider

if ! command -v aws &> /dev/null; then
    echo -e "${RED}❌ AWS CLI no está instalado. Instalando...${RESET}"
    (sudo apt update -qq && sudo apt install -y awscli) & spinner
else
    echo -e "${GREEN}✔️ AWS CLI está instalado.${RESET}"
fi

# PASO 2: Verificar credenciales de AWS
divider
echo -e "${BOLD}${CYAN}🔐 PASO 2: Verificando credenciales de AWS...${RESET}"
divider

if aws sts get-caller-identity --output json > /dev/null 2>&1; then
    echo -e "${GREEN}🔐🔓 Credenciales de AWS válidas detectadas.${RESET}"
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

# PASO 3: Verificar jq
if ! command -v jq &> /dev/null; then
    echo -e "${YELLOW}📦 Instalando jq...${RESET}"
    (sudo apt update -qq && sudo apt install -y jq) & spinner
fi

# PASO 4: Ingreso del dominio
divider
echo -e "${BOLD}${CYAN}🌐 PASO 3: Ingreso del dominio de origen${RESET}"
divider
while true; do
    read -p $'\e[1;94m🌐 Ingrese el dominio de origen (ej: tu.dominio.com): \e[0m' ORIGIN_DOMAIN_RAW
    ORIGIN_DOMAIN=$(echo "$ORIGIN_DOMAIN_RAW" | tr '[:upper:]' '[:lower:]' | xargs)

    if [[ -z "$ORIGIN_DOMAIN" ]]; then
        echo -e "${RED}❌ El dominio no puede estar vacío. Intente de nuevo.${RESET}"
        continue
    fi

    if [[ "$ORIGIN_DOMAIN" == http://* || "$ORIGIN_DOMAIN" == https://* ]]; then
        echo -e "${RED}❌ No incluya 'http://' ni 'https://' en el dominio.${RESET}"
        continue
    fi

    if ! [[ "$ORIGIN_DOMAIN" =~ ^[a-z0-9.-]+$ ]]; then
        echo -e "${RED}❌ Dominio inválido. Use letras minúsculas, números, guiones y puntos.${RESET}"
        continue
    fi

    echo -e "${YELLOW}🔎 Usando el dominio: ${BOLD}${ORIGIN_DOMAIN}${RESET}"
    read -p $'\e[1;93m➡️ ¿Confirmar dominio? (s/n): \e[0m' CONFIRMAR
    case "${CONFIRMAR,,}" in
        s|si|y|yes) break ;;
        n|no) echo -e "${BLUE}🔁 Intentémoslo de nuevo...${RESET}" ;;
        *) echo -e "${RED}❗ Responda con 's' o 'n'.${RESET}" ;;
    esac
done

# PASO 5: Descripción de la distribución
read -p $'\e[1;95m📝 Ingrese una descripción para la distribución [Default: Domain_1]: \e[0m' DESCRIPTION
DESCRIPTION=$(echo "$DESCRIPTION" | xargs)
[ -z "$DESCRIPTION" ] && DESCRIPTION="Domain_1"
REFERENCE="cf-ui-$(date +%s)"

# PASO 6: Crear archivo de configuración JSON
divider
echo -e "${BOLD}${CYAN}🛠️ PASO 4: Generando archivo de configuración...${RESET}"

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

# PASO 7: Crear distribución
divider
echo -e "${BOLD}${CYAN}📡 PASO 5: Creando la distribución en CloudFront...${RESET}"
if aws cloudfront create-distribution --distribution-config file://config_cloudfront.json > salida_cloudfront.json 2>error.log; then
    DOMAIN=$(jq -r '.Distribution.DomainName' salida_cloudfront.json)
    echo -e "${GREEN}\n🎯 ¡Distribución creada exitosamente!${RESET}"
    echo -e "${MAGENTA}🌍 URL de acceso: ${BOLD}https://${DOMAIN}${RESET}"
else
    echo -e "${RED}💥 Error al crear la distribución.${RESET}"
    echo -e "${YELLOW}📄 Ver detalles en: ${BOLD}error.log${RESET}"
    cat error.log
fi

# PASO 8: Limpieza final
divider
echo -e "${BLUE}🗑️ Limpiando archivos temporales...${RESET}"
for f in config_cloudfront.json salida_cloudfront.json error.log; do
  [ -f "$f" ] && rm -f "$f"
done

# Autodestrucción segura
if [[ -f "$0" ]]; then
    echo -e "${RED}🧨 Eliminando el script: ${BOLD}$0${RESET}"
    rm -- "$0"
fi

# Créditos
divider
echo -e "${GREEN}✅ Proceso completado sin errores.${RESET}"
echo -e "${MAGENTA}🌐 Dominio configurado: ${BOLD}${ORIGIN_DOMAIN}${RESET}"
echo -e "${MAGENTA}📄 Descripción: ${DESCRIPTION}${RESET}"
echo -e "${MAGENTA}🕒 Tiempo: $(date)${RESET}"
echo -e "${BOLD}${CYAN}🔧 Créditos a 👾 Leo Duarte${RESET}"
