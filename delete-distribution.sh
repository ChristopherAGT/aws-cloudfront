#!/bin/bash

clear

# ╔══════════════════════════════════════════════════════════╗
# ║        ❌ ELIMINADOR DE DISTRIBUCIONES - CLOUDFRONT      ║
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
echo "║        ❌ ELIMINADOR DE DISTRIBUCIONES - CLOUDFRONT      ║"
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

# 📋 Cabecera de tabla
echo ""
echo -e "${BOLD}${CYAN}╔═══════════════════════════════════════════════════════════════════════════════════════════════════╗${RESET}"
printf "${BOLD}${CYAN}║ %-2s │ %-32s │ %-40s │ %-21s │ %-8s ║${RESET}\n" \
  "Nº" "Origen actual" "Dominio CloudFront" "Descripción" "Estado"
echo -e "${BOLD}${CYAN}╟───────────────────────────────────────────────────────────────────────────────────────────────────╢${RESET}"

# 📄 Mostrar las filas de la tabla
declare -a IDS
for ((i = 0; i < COUNT; i++)); do
    ID=$(echo "$DISTROS" | jq -r ".DistributionList.Items[$i].Id")
    IDS[$i]="$ID"

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

echo ""

# Selección válida del usuario
while true; do
    read -p $'\e[1;93m🧩 Seleccione la distribución que desea eliminar: \e[0m' SELECCION
    INDEX=$((SELECCION - 1))
    if [[ "$SELECCION" =~ ^[0-9]+$ ]] && [ "$INDEX" -ge 0 ] && [ "$INDEX" -lt "$COUNT" ]; then
        break
    else
        echo -e "${RED}❌ Seleccione una distribución válida.${RESET}"
    fi
done

ID="${IDS[$INDEX]}"

# Obtener configuración y ETag actual
aws cloudfront get-distribution-config --id "$ID" > temp-config.json
ETAG=$(jq -r '.ETag' temp-config.json)

echo -e "${YELLOW}⚠️ Está por eliminar la distribución seleccionada.${RESET}"

# Confirmar s/n con validación
while true; do
    read -p $'\e[1;91m❓ ¿Confirmar eliminación? (s/n): \e[0m' CONFIRMAR
    CONFIRMAR=$(echo "$CONFIRMAR" | tr '[:upper:]' '[:lower:]')

    if [[ "$CONFIRMAR" == "s" ]]; then
        echo -e "${BLUE}⏳ Desactivando distribución antes de eliminar...${RESET}"

        # Modificar Enabled a false en DistributionConfig y guardar sólo DistributionConfig en disabled-config.json
        jq '.DistributionConfig | .Enabled = false' temp-config.json > disabled-config.json

        # Actualizar distribución con Enabled=false
        if ! aws cloudfront update-distribution --id "$ID" --if-match "$ETAG" --distribution-config file://disabled-config.json > /dev/null 2>&1; then
            echo -e "${RED}❌ Error al desactivar la distribución. Abortando.${RESET}"
            rm -f temp-config.json disabled-config.json
            exit 1
        fi

        echo -e "${BLUE}⌛ Esperando que la distribución se desactive...${RESET}"

        # Spinner simple
        spinner="/-\|"
        i=0

        # Esperar hasta que la distribución esté desactivada
        while true; do
            sleep 3
            STATUS=$(aws cloudfront get-distribution-config --id "$ID" | jq -r '.DistributionConfig.Enabled')
            if [[ "$STATUS" == "false" ]]; then
                break
            fi
            printf "\r${BLUE}... esperando que se desactive ${spinner:i++%${#spinner}:1}${RESET}"
        done
        printf "\r${GREEN}✅ Distribución desactivada. Procediendo a eliminar...       ${RESET}\n"

        # Obtener nuevo ETag para eliminar
        NEW_ETAG=$(aws cloudfront get-distribution-config --id "$ID" | jq -r '.ETag')

        # Intentar eliminar la distribución
        if aws cloudfront delete-distribution --id "$ID" --if-match "$NEW_ETAG"; then
            echo -e "${GREEN}✅ Distribución eliminada exitosamente.${RESET}"
        else
            echo -e "${RED}❌ Error al eliminar la distribución.${RESET}"
        fi

        # Limpieza
        rm -f temp-config.json disabled-config.json
        break

    elif [[ "$CONFIRMAR" == "n" ]]; then
        echo -e "${BLUE}🔁 Operación cancelada.${RESET}"
        break
    else
        echo -e "${RED}❌ Opción inválida. Por favor seleccione 's' o 'n'.${RESET}"
    fi
done

divider
echo -e "${BOLD}${CYAN}🧼 Gracias por usar el eliminador de distribuciones.${RESET}"
