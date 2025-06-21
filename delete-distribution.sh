#!/bin/bash

clear

# ╔══════════════════════════════════════════════════════════╗
# ║        ❌ ELIMINADOR INTERACTIVO DE DISTRIBUCIONES CF    ║
# ╚══════════════════════════════════════════════════════════╝

# 🎨 Colores
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

# 🧾 Encabezado
echo -e "${CYAN}"
echo "╔══════════════════════════════════════════════════════════╗"
echo "║        ❌ ELIMINADOR DE DISTRIBUCIONES - CLOUDFRONT    ║"
echo "╚══════════════════════════════════════════════════════════╝"
echo -e "${RESET}"

# 🧪 Verificar dependencias
if ! command -v aws &>/dev/null || ! command -v jq &>/dev/null; then
    echo -e "${RED}❌ Este script requiere AWS CLI y jq.${RESET}"
    exit 1
fi

# 🔍 Obtener lista de distribuciones
divider
echo -e "${BOLD}${CYAN}🔍 Buscando distribuciones activas...${RESET}"
divider

DISTROS=$(aws cloudfront list-distributions --output json)
COUNT=$(echo "$DISTROS" | jq '.DistributionList.Items | length')

if [ "$COUNT" -eq 0 ]; then
    echo -e "${YELLOW}⚠️ No se encontraron distribuciones disponibles.${RESET}"
    exit 0
fi

# 📋 Encabezado de la tabla
echo ""
echo -e "${BOLD}${CYAN}╔═══════════════════════════════════════════════════════════════════════════════════════════════════╗${RESET}"
printf "${BOLD}${CYAN}║ %-2s │ %-32s │ %-40s │ %-20s │ %-8s ║${RESET}\n" \
  "Nº" "Origen" "Dominio CloudFront" "Descripción" "Creación"
echo -e "${BOLD}${CYAN}╟───────────────────────────────────────────────────────────────────────────────────────────────────╢${RESET}"

# 📄 Mostrar filas de la tabla
declare -a IDS
for ((i = 0; i < COUNT; i++)); do
    ID=$(echo "$DISTROS" | jq -r ".DistributionList.Items[$i].Id")
    IDS[$i]="$ID"

    ORIGIN=$(echo "$DISTROS" | jq -r ".DistributionList.Items[$i].Origins.Items[0].DomainName")
    DOMAIN=$(echo "$DISTROS" | jq -r ".DistributionList.Items[$i].DomainName")
    COMMENT=$(echo "$DISTROS" | jq -r ".DistributionList.Items[$i].Comment")
    CREATED=$(echo "$DISTROS" | jq -r ".DistributionList.Items[$i].LastModifiedTime" | cut -d'T' -f1)

    printf "${CYAN}║${RESET} %-2s │ %-32s │ %-40s │ %-20s │ %-8s ${CYAN}║${RESET}\n" \
      "$((i+1))" "$ORIGIN" "$DOMAIN" "$COMMENT" "$CREATED"
done

# 🔚 Pie de la tabla
echo -e "${BOLD}${CYAN}╚═══════════════════════════════════════════════════════════════════════════════════════════════════╝${RESET}"

# 🔢 Selección de distribución
echo ""
while true; do
    read -p $'\e[1;93m🔢 Seleccione la distribución a eliminar: \e[0m' SELECCION
    INDEX=$((SELECCION - 1))

    if [[ "$SELECCION" =~ ^[0-9]+$ ]] && [ "$INDEX" -ge 0 ] && [ "$INDEX" -lt "$COUNT" ]; then
        break
    else
        echo -e "${RED}❌ Selección inválida. Intente nuevamente.${RESET}"
    fi
done

ID="${IDS[$INDEX]}"
ETAG=$(aws cloudfront get-distribution-config --id "$ID" | jq -r '.ETag')

# ⚠️ Confirmación
echo -e "${YELLOW}⚠️ Está por eliminar la distribución seleccionada (ID: ${BOLD}${ID}${RESET}${YELLOW}).${RESET}"
read -p $'\e[1;91m❓ ¿Confirmar eliminación? (s/n): \e[0m' CONFIRMAR

if [[ "${CONFIRMAR,,}" =~ ^(s|si|y|yes)$ ]]; then
    echo -e "${BLUE}⏳ Desactivando distribución antes de eliminar...${RESET}"

    aws cloudfront get-distribution-config --id "$ID" > temp-config.json
    jq '.DistributionConfig.Enabled = false' temp-config.json > disabled-config.json

    aws cloudfront update-distribution \
        --id "$ID" \
        --if-match "$ETAG" \
        --distribution-config file://disabled-config.json > /dev/null

    echo -e "${BLUE}⌛ Esperando propagación...${RESET}"
    sleep 10

    NEW_ETAG=$(aws cloudfront get-distribution-config --id "$ID" | jq -r '.ETag')

    echo -e "${RED}🧨 Eliminando distribución...${RESET}"
    if aws cloudfront delete-distribution --id "$ID" --if-match "$NEW_ETAG"; then
        echo -e "${GREEN}✅ Distribución eliminada exitosamente.${RESET}"
    else
        echo -e "${RED}❌ Error al eliminar la distribución.${RESET}"
    fi

    # 🧹 Limpieza
    rm -f temp-config.json disabled-config.json
else
    echo -e "${BLUE}🔁 Operación cancelada.${RESET}"
fi

divider
echo -e "${MAGENTA}🧼 Gracias por usar el eliminador de distribuciones CF.${RESET}"

# 🗑️ Autodestrucción del script
rm -- "$0"
