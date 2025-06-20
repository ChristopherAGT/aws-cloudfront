#!/bin/bash

clear

# ╔══════════════════════════════════════════════════════════╗
# ║       ✏️ EDITOR DE DOMINIOS DE ORIGEN - CLOUDFRONT       ║
# ╚══════════════════════════════════════════════════════════╝

# Colores
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

echo -e "${CYAN}"
echo "╔══════════════════════════════════════════════════════════╗"
echo "║       ✏️ EDITOR DE DOMINIOS DE ORIGEN - CLOUDFRONT       ║"
echo "╚══════════════════════════════════════════════════════════╝"
echo -e "${RESET}"

# Verificar herramientas
if ! command -v aws &>/dev/null || ! command -v jq &>/dev/null; then
    echo -e "${RED}❌ Este script requiere AWS CLI y jq.${RESET}"
    exit 1
fi

# Obtener lista de distribuciones
divider
echo -e "${BOLD}${CYAN}🔍 Cargando distribuciones disponibles...${RESET}"
divider

DISTROS=$(aws cloudfront list-distributions --output json)
COUNT=$(echo "$DISTROS" | jq '.DistributionList.Items | length')

if [ "$COUNT" -eq 0 ]; then
    echo -e "${YELLOW}⚠️ No se encontraron distribuciones disponibles.${RESET}"
    exit 0
fi

# Imprimir cabecera de tabla
printf "${BOLD}${CYAN}%-4s│ %-22s│ %-30s│ %-20s│ %-20s${RESET}\n" \
  " Nº" "Origen actual" "Dominio CloudFront" "Descripción" "Creación"
printf "${CYAN}────┼────────────────────────┼────────────────────────────────┼──────────────────────┼────────────────────────────${RESET}\n"

# Almacenar IDs y Configurations
declare -a IDS
declare -a CONFIGS

for ((i = 0; i < COUNT; i++)); do
    ID=$(echo "$DISTROS" | jq -r ".DistributionList.Items[$i].Id")
    IDS[$i]="$ID"

    ORIGIN=$(echo "$DISTROS" | jq -r ".DistributionList.Items[$i].Origins.Items[0].DomainName")
    COMMENT=$(echo "$DISTROS" | jq -r ".DistributionList.Items[$i].Comment")
    DOMAIN=$(echo "$DISTROS" | jq -r ".DistributionList.Items[$i].DomainName")
    CREATED=$(echo "$DISTROS" | jq -r ".DistributionList.Items[$i].LastModifiedTime")

    printf "%-4s│ %-22s│ %-30s│ %-20s│ %-20s\n" \
      "$((i+1))" "$ORIGIN" "$DOMAIN" "$COMMENT" "$CREATED"
done

echo ""
read -p $'\e[1;93m🔢 Seleccione el número de la distribución que desea editar: \e[0m' SELECCION
INDEX=$((SELECCION - 1))

if ! [[ "$SELECCION" =~ ^[0-9]+$ ]] || [ "$INDEX" -lt 0 ] || [ "$INDEX" -ge "$COUNT" ]; then
    echo -e "${RED}❌ Número inválido.${RESET}"
    exit 1
fi

ID="${IDS[$INDEX]}"

echo -e "${BLUE}📥 Descargando configuración actual...${RESET}"
aws cloudfront get-distribution-config --id "$ID" > config_original.json
ETAG=$(jq -r '.ETag' config_original.json)
CONFIG=$(jq '.DistributionConfig' config_original.json)

ORIGIN_ACTUAL=$(echo "$CONFIG" | jq -r '.Origins.Items[0].DomainName')
echo -e "${YELLOW}🌐 Dominio de origen actual: ${BOLD}${ORIGIN_ACTUAL}${RESET}"

# Solicitar nuevo origen
read -p $'\e[1;96m✏️ Ingrese el nuevo dominio de origen: \e[0m' NUEVO_ORIGEN
NUEVO_ORIGEN=$(echo "$NUEVO_ORIGEN" | xargs | tr '[:upper:]' '[:lower:]')

if [[ -z "$NUEVO_ORIGEN" ]]; then
    echo -e "${RED}❌ No puede dejar el campo vacío.${RESET}"
    exit 1
fi

# Confirmar
echo -e "${YELLOW}⚠️ Se cambiará el dominio de origen a: ${BOLD}${NUEVO_ORIGEN}${RESET}"
read -p $'\e[1;93m¿Confirmar el cambio? (s/n): \e[0m' CONFIRMAR

if [[ "${CONFIRMAR,,}" =~ ^(s|si|y|yes)$ ]]; then
    echo -e "${BLUE}🔧 Actualizando configuración...${RESET}"

    jq --arg newdomain "$NUEVO_ORIGEN" \
        '.Origins.Items[0].DomainName = $newdomain' \
        <<< "$CONFIG" > nueva_config.json

    aws cloudfront update-distribution \
        --id "$ID" \
        --if-match "$ETAG" \
        --distribution-config file://nueva_config.json > /dev/null

    echo -e "${GREEN}✅ Dominio de origen actualizado correctamente.${RESET}"
else
    echo -e "${BLUE}🔁 Operación cancelada.${RESET}"
fi

# Limpieza
rm -f config_original.json nueva_config.json

divider
echo -e "${MAGENTA}🧼 Gracias por usar el editor de orígenes.${RESET}"
