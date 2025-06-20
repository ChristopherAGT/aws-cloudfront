#!/bin/bash

clear

# ╔══════════════════════════════════════════════════════════╗
# ║        ❌ ELIMINADOR INTERACTIVO DE DISTRIBUCIONES CF    ║
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
echo "║        ❌ ELIMINADOR INTERACTIVO DE DISTRIBUCIONES CF    ║"
echo "╚══════════════════════════════════════════════════════════╝"
echo -e "${RESET}"

# Verificar dependencias
if ! command -v aws &>/dev/null || ! command -v jq &>/dev/null; then
    echo -e "${RED}❌ Este script requiere AWS CLI y jq.${RESET}"
    exit 1
fi

# Obtener lista de distribuciones
divider
echo -e "${BOLD}${CYAN}🔍 Buscando distribuciones activas...${RESET}"
divider

DISTROS=$(aws cloudfront list-distributions --output json)
COUNT=$(echo "$DISTROS" | jq '.DistributionList.Items | length')

if [ "$COUNT" -eq 0 ]; then
    echo -e "${YELLOW}⚠️ No se encontraron distribuciones disponibles.${RESET}"
    exit 0
fi

# Imprimir cabecera de tabla (sin ID)
printf "${BOLD}${CYAN}%-4s│ %-22s│ %-30s│ %-18s│ %-20s${RESET}\n" \
  " Nº" "Origen" "Dominio CloudFront" "Descripción" "Creación"
printf "${CYAN}────┼────────────────────────────┼────────────────────────────────┼──────────────────────┼────────────────────────────${RESET}\n"

# Declarar arreglo de IDs ocultos
declare -a IDS

# Mostrar distribuciones como tabla (sin mostrar ID)
for ((i = 0; i < COUNT; i++)); do
    IDS[$i]=$(echo "$DISTROS" | jq -r ".DistributionList.Items[$i].Id")
    ORIGIN=$(echo "$DISTROS" | jq -r ".DistributionList.Items[$i].Origins.Items[0].DomainName")
    COMMENT=$(echo "$DISTROS" | jq -r ".DistributionList.Items[$i].Comment")
    DOMAIN=$(echo "$DISTROS" | jq -r ".DistributionList.Items[$i].DomainName")
    CREATED=$(echo "$DISTROS" | jq -r ".DistributionList.Items[$i].LastModifiedTime")

    printf "%-4s│ %-22s│ %-30s│ %-18s│ %-20s\n" \
      "$((i+1))" "$ORIGIN" "$DOMAIN" "$COMMENT" "$CREATED"
done

echo ""

# Selección del usuario
read -p $'\e[1;93m🧩 Ingrese el número de la distribución a eliminar: \e[0m' SELECCION
INDEX=$((SELECCION - 1))

if ! [[ "$SELECCION" =~ ^[0-9]+$ ]] || [ "$INDEX" -lt 0 ] || [ "$INDEX" -ge "$COUNT" ]; then
    echo -e "${RED}❌ Selección inválida.${RESET}"
    exit 1
fi

# Obtener ID y ETag usando índice
ID="${IDS[$INDEX]}"
ETAG=$(aws cloudfront get-distribution-config --id "$ID" | jq -r '.ETag')

echo -e "${YELLOW}⚠️ Está por eliminar la distribución seleccionada.${RESET}"
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

    # Limpiar
    rm -f temp-config.json disabled-config.json
else
    echo -e "${BLUE}🔁 Operación cancelada.${RESET}"
fi

divider
echo -e "${BOLD}${CYAN}🧼 Gracias por usar el eliminador de distribuciones CF.${RESET}"
