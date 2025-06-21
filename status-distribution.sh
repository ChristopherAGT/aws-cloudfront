#!/bin/bash

clear

# ╔══════════════════════════════════════════════════════════╗
# ║       📊 ESTADO DE DISTRIBUCIONES - CLOUDFRONT           ║
# ╚══════════════════════════════════════════════════════════╝

# Colores
RED='\e[1;91m'
GREEN='\e[1;92m'
YELLOW='\e[1;93m'
BLUE='\e[1;94m'
CYAN='\e[1;96m'
BOLD='\e[1m'
RESET='\e[0m'

divider() {
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
}

echo -e "${CYAN}"
echo "╔══════════════════════════════════════════════════════════╗"
echo "║       📊 ESTADO DE DISTRIBUCIONES - CLOUDFRONT           ║"
echo "╚══════════════════════════════════════════════════════════╝"
echo -e "${RESET}"

# Verificar dependencias
if ! command -v aws &>/dev/null || ! command -v jq &>/dev/null; then
    echo -e "${RED}❌ Este script requiere AWS CLI y jq.${RESET}"
    exit 1
fi

divider
echo -e "${BOLD}${CYAN}🔍 Obteniendo lista de distribuciones activas...${RESET}"
divider

RAW_OUTPUT=$(aws cloudfront list-distributions --output json 2>/dev/null)

if [[ $? -ne 0 || -z "$RAW_OUTPUT" || "$RAW_OUTPUT" == "null" ]]; then
    echo -e "${RED}❌ Error al obtener la lista de distribuciones. Verifica conexión, credenciales o permisos.${RESET}"
    exit 1
fi

# Aquí chequeamos si "Items" existe, no es nulo y es un array con al menos 1 elemento
HAS_ITEMS=$(echo "$RAW_OUTPUT" | jq '.DistributionList.Items != null and (.DistributionList.Items | type) == "array" and (.DistributionList.Items | length) > 0')

if [[ "$HAS_ITEMS" != "true" ]]; then
    echo -e "${YELLOW}⚠️ No se encontraron distribuciones activas en tu cuenta.${RESET}"
    exit 0
fi

COUNT=$(echo "$RAW_OUTPUT" | jq '.DistributionList.Items | length')

DISTROS="$RAW_OUTPUT"

# Cabecera tabla
echo ""
echo -e "${BOLD}${CYAN}╔════════════════════════════════════════════════════════════════════════════════════════════════════╗${RESET}"
printf "${BOLD}${CYAN}║ %-2s │ %-32s │ %-40s │ %-20s │ %-12s ║${RESET}\n" \
  "Nº" "Origen actual" "Dominio CloudFront" "Descripción" "Estado"
echo -e "${BOLD}${CYAN}╟────────────────────────────────────────────────────────────────────────────────────────────────────╢${RESET}"

INDEX=0
echo "$DISTROS" | jq -c '.DistributionList.Items[]' | while read -r DISTRO; do
    ID=$(echo "$DISTRO" | jq -r '.Id // "-"')
    ORIGIN=$(echo "$DISTRO" | jq -r '.Origins.Items[0].DomainName // "-"')
    DOMAIN=$(echo "$DISTRO" | jq -r '.DomainName // "-"')
    COMMENT=$(echo "$DISTRO" | jq -r '.Comment // "-"')
    ENABLED=$(echo "$DISTRO" | jq -r '.Enabled // "false"')
    STATUS=$(echo "$DISTRO" | jq -r '.Status // "unknown"')

    if [[ "$STATUS" == "InProgress" ]]; then
        STATE_RAW="Desplegando"
        STATE_COLOR="${YELLOW}Desplegando${RESET}"
    else
        if [[ "$ENABLED" == "true" ]]; then
            STATE_RAW="Enabled"
            STATE_COLOR="${GREEN}Enabled${RESET}"
        else
            STATE_RAW="Disabled"
            STATE_COLOR="${RED}Disabled${RESET}"
        fi
    fi

    STATE_LEN=${#STATE_RAW}
    PADDING=$((12 - STATE_LEN))
    SPACES=$(printf '%*s' "$PADDING" '')

    INDEX=$((INDEX + 1))
    printf "${CYAN}║${RESET} %-2s │ %-32s │ %-40s │ %-20s │ " "$INDEX" "$ORIGIN" "$DOMAIN" "$COMMENT"
    echo -e "$STATE_COLOR$SPACES${CYAN} ║${RESET}"
done

echo -e "${BOLD}${CYAN}╚════════════════════════════════════════════════════════════════════════════════════════════════════╝${RESET}"
