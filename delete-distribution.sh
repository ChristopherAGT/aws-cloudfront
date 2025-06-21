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
echo "╔═══════════════════════════════════════════════════════╗"
echo "║        ❌ ELIMINADOR INTERACTIVO DE DISTRIBUCIONES CF  ║"
echo "╚═══════════════════════════════════════════════════════╝"
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

# Imprimir cabecera de tabla
echo ""
echo -e "${BOLD}${CYAN}╔═══════════════════════════════════════════════════════════════════════════════════════════════════╗${RESET}"
printf "${BOLD}${CYAN}║ %-2s │ %-32s │ %-40s │ %-20s │ %-9s ║${RESET}\n" \
  "Nº" "Origen" "Dominio CloudFront" "Descripción" "Estado"
echo -e "${BOLD}${CYAN}╟───────────────────────────────────────────────────────────────────────────────────────────────────╢${RESET}"

# Declarar arreglo para IDs
declare -a IDS

# Mostrar distribuciones con formato igual que editor
for ((i = 0; i < COUNT; i++)); do
    IDS[$i]=$(echo "$DISTROS" | jq -r ".DistributionList.Items[$i].Id")
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

    # Calcular padding para alinear estado (9 espacios)
    STATE_LEN=${#STATE_RAW}
    PADDING=$((9 - STATE_LEN))
    SPACES=$(printf '%*s' "$PADDING" '')

    # Imprimir fila con formato
    printf "${CYAN}║${RESET} %-2s │ %-32s │ %-40s │ %-20s │ %s%s${CYAN} ║${RESET}\n" \
      "$((i+1))" "$ORIGIN" "$DOMAIN" "$COMMENT" "$STATE_COLOR" "$SPACES"
done

# Pie de tabla
echo -e "${BOLD}${CYAN}╚═══════════════════════════════════════════════════════════════════════════════════════════════════╝${RESET}"
echo ""

# Selección con validación
while true; do
    read -p $'\e[1;93m🧩 Ingrese el número de la distribución a eliminar: \e[0m' SELECCION
    INDEX=$((SELECCION - 1))

    if [[ "$SELECCION" =~ ^[0-9]+$ ]] && [ "$INDEX" -ge 0 ] && [ "$INDEX" -lt "$COUNT" ]; then
        break
    else
        echo -e "${RED}❌ Selección inválida. Por favor ingrese un número válido.${RESET}"
    fi
done

ID="${IDS[$INDEX]}"
ETAG=$(aws cloudfront get-distribution-config --id "$ID" | jq -r '.ETag')

# Confirmación con bucle válido s/n
while true; do
    read -p $'\e[1;91m❓ ¿Confirmar eliminación? (s/n): \e[0m' CONFIRMAR
    CONFIRMAR=$(echo "$CONFIRMAR" | tr '[:upper:]' '[:lower:]')

    if [[ "$CONFIRMAR" == "s" ]]; then
        echo -e "${BLUE}⏳ Desactivando distribución antes de eliminar...${RESET}"

        # Desactivar distribución
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

        # Limpiar archivos temporales
        rm -f temp-config.json disabled-config.json
        break

    elif [[ "$CONFIRMAR" == "n" ]]; then
        echo -e "${BLUE}🔁 Operación cancelada.${RESET}"
        exit 0

    else
        echo -e "${RED}❌ Opción inválida. Por favor seleccione 's' o 'n'.${RESET}"
    fi
done

divider
echo -e "${BOLD}${CYAN}🧼 Gracias por usar el eliminador de distribuciones CF.${RESET}"
