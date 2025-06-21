#!/bin/bash

clear

# ╔══════════════════════════════════════════════════════════╗
# ║       📊 ESTADO DE DISTRIBUCIONES - CLOUDFRONT                     ║
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

# 🔍 Verificar dependencias
if ! command -v aws &>/dev/null || ! command -v jq &>/dev/null; then
    echo -e "${RED}❌ Este script requiere AWS CLI y jq.${RESET}"
    exit 1
fi

# 🔍 Obteniendo lista de distribuciones
divider
echo -e "${BOLD}${CYAN}🔍 Obteniendo lista de distribuciones activas...${RESET}"
divider

# 📥 Ejecutar comando AWS con manejo de errores
RAW_OUTPUT=$(aws cloudfront list-distributions --output json 2>&1)
STATUS=$?

if [[ $STATUS -ne 0 ]]; then
    echo -e "${RED}❌ Error al ejecutar AWS CLI: ${RAW_OUTPUT}${RESET}"
    echo -e "${RED}🔍 Verifica tu conexión, credenciales o permisos configurados.${RESET}"
    exit 1
fi

if [[ -z "$RAW_OUTPUT" || "$RAW_OUTPUT" == "null" ]]; then
    echo -e "${RED}❌ La respuesta de AWS CLI fue vacía o inválida.${RESET}"
    exit 1
fi

# 🧪 Validar si el campo Items existe (si no, no hay distribuciones)
HAS_ITEMS=$(echo "$RAW_OUTPUT" | jq -e '.DistributionList | has("Items")' 2>/dev/null)
if [[ "$HAS_ITEMS" != "true" ]]; then
    echo -e "${YELLOW}⚠️ No se encontraron distribuciones activas en tu cuenta.${RESET}"
    exit 0
fi

# 📊 Obtener cantidad de distribuciones
COUNT=$(echo "$RAW_OUTPUT" | jq '.DistributionList.Items | length')

DISTROS="$RAW_OUTPUT"

# 📋 Cabecera de tabla
echo ""
echo -e "${BOLD}${CYAN}╔═══════════════════════════════════════════════════════════════════════════════════════════════════╗${RESET}"
printf "${BOLD}${CYAN}║ %-2s │ %-32s │ %-40s │ %-21s │ %-8s ║${RESET}\n" \
  "Nº" "Origen actual" "Dominio CloudFront" "Descripción" "Estado"
echo -e "${BOLD}${CYAN}╟───────────────────────────────────────────────────────────────────────────────────────────────────╢${RESET}"

# 📄 Mostrar cada fila
for ((i = 0; i < COUNT; i++)); do
    ID=$(echo "$DISTROS" | jq -r ".DistributionList.Items[$i].Id")
    ORIGIN=$(echo "$DISTROS" | jq -r ".DistributionList.Items[$i].Origins.Items[0].DomainName")
    DOMAIN=$(echo "$DISTROS" | jq -r ".DistributionList.Items[$i].DomainName")
    COMMENT=$(echo "$DISTROS" | jq -r ".DistributionList.Items[$i].Comment")
    ENABLED=$(echo "$DISTROS" | jq -r ".DistributionList.Items[$i].Enabled")

    # Estado con color
    if [[ "$ENABLED" == "true" ]]; then
        STATE_RAW="Enabled"
        STATE_COLOR="${GREEN}Enabled${RESET}"
    else
        STATE_RAW="Disabled"
        STATE_COLOR="${RED}Disabled${RESET}"
    fi

    # Alineación final
    STATE_LEN=${#STATE_RAW}
    PADDING=$((8 - STATE_LEN))
    SPACES=$(printf '%*s' "$PADDING" '')

    # Imprimir fila
    printf "${CYAN}║${RESET} %-2s │ %-32s │ %-40s │ %-20s │ " "$((i+1))" "$ORIGIN" "$DOMAIN" "$COMMENT"
    echo -e "$STATE_COLOR$SPACES${CYAN} ║${RESET}"
done

# 📦 Cierre de tabla
echo -e "${BOLD}${CYAN}╚═══════════════════════════════════════════════════════════════════════════════════════════════════╝${RESET}"
