#!/bin/bash

clear

# ╔══════════════════════════════════════════════════════════╗
# ║ 🔁 ACTIVADOR / DESACTIVADOR DE DISTRIBUCIONES - CLOUDFRONT ║
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
echo "║ 🔁 ACTIVADOR / DESACTIVADOR DE DISTRIBUCIONES - CLOUDFRONT         ║"
echo "╚══════════════════════════════════════════════════════════╝"
echo -e "${RESET}"

# Verificar dependencias
if ! command -v aws &>/dev/null || ! command -v jq &>/dev/null; then
    echo -e "${RED}❌ Este script requiere AWS CLI y jq.${RESET}"
    exit 1
fi

# Obtener lista de distribuciones
divider
echo -e "${BOLD}${CYAN}🔍 Buscando distribuciones disponibles...${RESET}"
divider

DISTROS=$(aws cloudfront list-distributions --output json)
COUNT=$(echo "$DISTROS" | jq '.DistributionList.Items | length')

if [ "$COUNT" -eq 0 ]; then
    echo -e "${YELLOW}⚠️ No se encontraron distribuciones.${RESET}"
    exit 0
fi

# Cabecera de tabla
echo ""
echo -e "${BOLD}${CYAN}╔═══════════════════════════════════════════════════════════════════════════════════════════════════╗${RESET}"
printf "${BOLD}${CYAN}║ %-2s │ %-32s │ %-40s │ %-21s │ %-8s ║${RESET}\n" \
  "Nº" "Origen actual" "Dominio CloudFront" "Descripción" "Estado"
echo -e "${BOLD}${CYAN}╟───────────────────────────────────────────────────────────────────────────────────────────────────╢${RESET}"

# Mostrar filas
declare -a IDS
for ((i = 0; i < COUNT; i++)); do
    ID=$(echo "$DISTROS" | jq -r ".DistributionList.Items[$i].Id")
    IDS[$i]="$ID"

    ORIGIN=$(echo "$DISTROS" | jq -r ".DistributionList.Items[$i].Origins.Items[0].DomainName")
    DOMAIN=$(echo "$DISTROS" | jq -r ".DistributionList.Items[$i].DomainName")
    COMMENT=$(echo "$DISTROS" | jq -r ".DistributionList.Items[$i].Comment")
    ENABLED=$(echo "$DISTROS" | jq -r ".DistributionList.Items[$i].Enabled")

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

    printf "${CYAN}║${RESET} %-2s │ %-32s │ %-40s │ %-20s │ " "$((i+1))" "$ORIGIN" "$DOMAIN" "$COMMENT"
    echo -e "$STATE_COLOR$SPACES${CYAN} ║${RESET}"
done

echo -e "${BOLD}${CYAN}╚═══════════════════════════════════════════════════════════════════════════════════════════════════╝${RESET}"
echo ""

# Selección del usuario
while true; do
    read -p $'\e[1;93m🧩 Seleccione la distribución que desea modificar: \e[0m' SELECCION
    INDEX=$((SELECCION - 1))
    if [[ "$SELECCION" =~ ^[0-9]+$ ]] && [ "$INDEX" -ge 0 ] && [ "$INDEX" -lt "$COUNT" ]; then
        break
    else
        echo -e "${RED}❌ Seleccione una opción válida.${RESET}"
    fi
done

ID="${IDS[$INDEX]}"
aws cloudfront get-distribution-config --id "$ID" > temp-config.json
ETAG=$(jq -r '.ETag' temp-config.json)
CURRENT_STATE=$(jq -r '.DistributionConfig.Enabled' temp-config.json)

# Mostrar estado actual
if [[ "$CURRENT_STATE" == "true" ]]; then
    echo -e "${YELLOW}⚠️ Actualmente la distribución está ${GREEN}ACTIVA${RESET}${YELLOW}.${RESET}"
    OPCION="desactivar"
    NEW_STATE="false"
else
    echo -e "${YELLOW}⚠️ Actualmente la distribución está ${RED}INACTIVA${RESET}${YELLOW}.${RESET}"
    OPCION="activar"
    NEW_STATE="true"
fi

# Confirmar
while true; do
    read -p $'\e[1;91m❓ ¿Desea confirmar la acción? (s/n): \e[0m' CONFIRMAR
    CONFIRMAR=$(echo "$CONFIRMAR" | tr '[:upper:]' '[:lower:]')
    if [[ "$CONFIRMAR" == "s" ]]; then
        break
    elif [[ "$CONFIRMAR" == "n" ]]; then
        echo -e "${BLUE}🔁 Operación cancelada.${RESET}"
        exit 0
    else
        echo -e "${RED}❌ Ingrese 's' o 'n'.${RESET}"
    fi
done

echo -e "${BLUE}⏳ Procesando solicitud para ${OPCION} la distribución...${RESET}"

jq --argjson enabled "$NEW_STATE" '.DistributionConfig.Enabled = $enabled | .DistributionConfig' temp-config.json > updated-config.json

if aws cloudfront update-distribution --id "$ID" --if-match "$ETAG" --distribution-config file://updated-config.json > /dev/null 2>&1; then
    # Spinner mientras se despliega
    echo -e "${BLUE}⌛ Esperando que se aplique el cambio...${RESET}"
    spinner=("⠋" "⠙" "⠸" "⠴" "⠦" "⠇")
    i=0
    while true; do
        sleep 1
        STATUS_DEPLOYED=$(aws cloudfront get-distribution --id "$ID" | jq -r '.Distribution.Status')
        if [[ "$STATUS_DEPLOYED" == "Deployed" ]]; then
            break
        fi
        echo -ne "\r${BLUE}⏳ Aplicando cambios ${spinner[i++ % ${#spinner[@]}]}${RESET}"
    done
    echo -e "\r${GREEN}✅ Cambio realizado exitosamente. La distribución ahora está ${NEW_STATE^^}.${RESET}"
else
    echo -e "${RED}❌ Error al aplicar los cambios. Abortando.${RESET}"
fi

# Limpiar archivos temporales
rm -f temp-config.json updated-config.json
divider
echo -e "${BOLD}${CYAN}🧼 Gracias por usar el activador/desactivador de distribuciones.${RESET}"
