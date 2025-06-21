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
echo "║       📊 ESTADO DE DISTRIBUCIONES - CLOUDFRONT                     ║"
echo "╚══════════════════════════════════════════════════════════╝"
echo -e "${RESET}"

# Verificar dependencias
if ! command -v aws &>/dev/null || ! command -v jq &>/dev/null; then
    echo -e "${RED}❌ Este script requiere AWS CLI y jq.${RESET}"
    exit 1
fi

# 🔍 Obtener lista de distribuciones activas
divider
echo -e "${BOLD}${CYAN}🔍 Obteniendo lista de distribuciones activas...${RESET}"
divider

# 📥 Obtener lista de distribuciones con manejo de errores
RAW_OUTPUT=$(aws cloudfront list-distributions --output json 2>/dev/null)

# ❌ Verificar si la salida está vacía o es 'null'
if [[ -z "$RAW_OUTPUT" || "$RAW_OUTPUT" == "null" ]]; then
    echo -e "${RED}❌ Error al obtener la lista de distribuciones. Verifica tu conexión, credenciales o permisos de AWS.${RESET}"
    exit 1
fi

# 📊 Extraer cantidad de distribuciones de forma segura
COUNT=$(echo "$RAW_OUTPUT" | jq -r '.DistributionList.Quantity // 0')

# 🧪 Validar que COUNT sea numérico
if ! [[ "$COUNT" =~ ^[0-9]+$ ]]; then
    echo -e "${RED}❌ Error al interpretar el número de distribuciones.${RESET}"
    exit 1
fi

# ⚠️ Mostrar mensaje si no hay distribuciones
if [ "$COUNT" -eq 0 ]; then
    echo -e "${YELLOW}⚠️ No se encontraron distribuciones activas en tu cuenta.${RESET}"
    exit 0
fi

# ✅ Si hay distribuciones, guardar para procesamiento posterior
DISTROS="$RAW_OUTPUT"

# 📋 Cabecera de tabla
echo ""
echo -e "${BOLD}${CYAN}╔═══════════════════════════════════════════════════════════════════════════════════════════════════╗${RESET}"
printf "${BOLD}${CYAN}║ %-2s │ %-32s │ %-40s │ %-21s │ %-8s ║${RESET}\n" \
  "Nº" "Origen actual" "Dominio CloudFront" "Descripción" "Estado"
echo -e "${BOLD}${CYAN}╟───────────────────────────────────────────────────────────────────────────────────────────────────╢${RESET}"

# 📄 Mostrar las filas de la tabla
for ((i = 0; i < COUNT; i++)); do
    ID=$(echo "$DISTROS" | jq -r ".DistributionList.Items[$i].Id")
    ORIGIN=$(echo "$DISTROS" | jq -r ".DistributionList.Items[$i].Origins.Items[0].DomainName")
    DOMAIN=$(echo "$DISTROS" | jq -r ".DistributionList.Items[$i].DomainName")
    COMMENT=$(echo "$DISTROS" | jq -r ".DistributionList.Items[$i].Comment")
    ENABLED=$(echo "$DISTROS" | jq -r ".DistributionList.Items[$i].Enabled")

    # Preparar estado con color
    if [[ "$ENABLED" == "true" ]]; then
        STATE_RAW="Enabled"
        STATE_COLOR="${GREEN}Enabled${RESET}"
    else
        STATE_RAW="Disabled"
        STATE_COLOR="${RED}Disabled${RESET}"
    fi

    STATE_LEN=${#STATE_RAW}
    PADDING=$((8 - STATE_LEN))
    SPACES=$(printf '%*s' "$PADDING" '')

    # Imprimir fila alineada
    printf "${CYAN}║${RESET} %-2s │ %-32s │ %-40s │ %-20s │ " "$((i+1))" "$ORIGIN" "$DOMAIN" "$COMMENT"
    echo -e "$STATE_COLOR$SPACES${CYAN} ║${RESET}"
done

# Pie de la tabla
echo -e "${BOLD}${CYAN}╚═══════════════════════════════════════════════════════════════════════════════════════════════════╝${RESET}"
