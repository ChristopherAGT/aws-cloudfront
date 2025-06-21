#!/bin/bash

clear  # Limpia pantalla al inicio

# ╔══════════════════════════════════════════════════════════╗
# ║       ✏️ EDITOR DE DOMINIOS DE ORIGEN - CLOUDFRONT                  ║
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
echo "║       ✏️ EDITOR DE DOMINIOS DE ORIGEN - CLOUDFRONT                 ║"
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

# 📋 Cabecera de tabla
echo ""
echo -e "${BOLD}${CYAN}╔═══════════════════════════════════════════════════════════════════════════════════════════════════╗${RESET}"
printf "${BOLD}${CYAN}║ %-2s │ %-32s │ %-40s │ %-21s │ %-8s ║${RESET}\n" \
  "Nº" "Origen actual" "Dominio CloudFront" "Descripción" "Estado"
echo -e "${BOLD}${CYAN}╟───────────────────────────────────────────────────────────────────────────────────────────────────╢${RESET}"

# 📄 Mostrar las filas de la tabla
for ((i = 0; i < COUNT; i++)); do
    ID=$(echo "$DISTROS" | jq -r ".DistributionList.Items[$i].Id")
    IDS[$i]="$ID"

    ORIGIN=$(echo "$DISTROS" | jq -r ".DistributionList.Items[$i].Origins.Items[0].DomainName")
    DOMAIN=$(echo "$DISTROS" | jq -r ".DistributionList.Items[$i].DomainName")
    COMMENT=$(echo "$DISTROS" | jq -r ".DistributionList.Items[$i].Comment")
    ENABLED=$(echo "$DISTROS" | jq -r ".DistributionList.Items[$i].Enabled")

    # 🟢 Preparar estado con color y sin color
if [[ "$ENABLED" == "true" ]]; then
    STATE_RAW="Enabled"
    STATE_COLOR="${GREEN}Enabled${RESET}"
else
    STATE_RAW="Disabled"
    STATE_COLOR="${RED}Disabled${RESET}"
fi

# 📏 Calcular espacios para que la columna tenga 9 caracteres visibles
STATE_LEN=${#STATE_RAW}
PADDING=$((8 - STATE_LEN))
SPACES=$(printf '%*s' "$PADDING" '')

# 🔲 Imprimir fila alineada
printf "${CYAN}║${RESET} %-2s │ %-32s │ %-40s │ %-20s │ " "$((i+1))" "$ORIGIN" "$DOMAIN" "$COMMENT"
echo -e "$STATE_COLOR$SPACES${CYAN} ║${RESET}"
done

# 🔚 Pie de la tabla
echo -e "${BOLD}${CYAN}╚═══════════════════════════════════════════════════════════════════════════════════════════════════╝${RESET}"

#Seleccion de distribución
echo ""
while true; do
    read -p $'\e[1;93m🔢 Seleccione la distribución que desea editar: \e[0m' SELECCION
    INDEX=$((SELECCION - 1))

    if [[ "$SELECCION" =~ ^[0-9]+$ ]] && [ "$INDEX" -ge 0 ] && [ "$INDEX" -lt "$COUNT" ]; then
        break
    else
        echo -e "${RED}❌ Seleccione una distribución válida.${RESET}"
    fi
done

ID="${IDS[$INDEX]}"

echo -e "${BLUE}📥 Descargando configuración actual...${RESET}"
aws cloudfront get-distribution-config --id "$ID" > config_original.json
ETAG=$(jq -r '.ETag' config_original.json)
CONFIG=$(jq '.DistributionConfig' config_original.json)

# 🔍 Obtener dominio actual
ORIGIN_ACTUAL=$(echo "$CONFIG" | jq -r '.Origins.Items[0].DomainName')

# 🌐 Resolver IP del dominio actual
IP_DOMINIO_ACTUAL=$(getent hosts "$ORIGIN_ACTUAL" | awk '{ print $1 }' | head -n 1)
if [[ -z "$IP_DOMINIO_ACTUAL" ]] && command -v dig &>/dev/null; then
    IP_DOMINIO_ACTUAL=$(dig +short "$ORIGIN_ACTUAL" | head -n 1)
fi
[[ -z "$IP_DOMINIO_ACTUAL" ]] && IP_DOMINIO_ACTUAL="IP no encontrada"

# 💬 Mostrar dominio + IP
echo -e "${YELLOW}🌐 Dominio de origen actual: ${BOLD}${ORIGIN_ACTUAL} (${IP_DOMINIO_ACTUAL})${RESET}"

# ✅ Función para validar dominio con mensajes detallados
validar_dominio() {
    local domain="$1"
    domain=$(echo "$domain" | tr '[:upper:]' '[:lower:]' | xargs)

    if [[ -z "$domain" ]]; then
        echo -e "${RED}❌ El dominio no puede estar vacío.${RESET}"
        return 1
    fi

    if [[ "$domain" == http://* || "$domain" == https://* ]]; then
        echo -e "${RED}❌ No incluya 'http://' ni 'https://' en el dominio.${RESET}"
        return 1
    fi

    if ! [[ "$domain" =~ ^([a-z0-9-]+\.)+[a-z]{2,}$ ]]; then
        echo -e "${RED}❌ Dominio inválido. Debe tener formato tipo 'ejemplo.com' o 'cdn.miweb.net'.${RESET}"
        return 1
    fi

    return 0
}

# 🔁 Solicitar nuevo dominio con validación completa
while true; do
    read -p $'\e[1;96m✏️ Ingrese su nuevo dominio de origen: \e[0m' NUEVO_ORIGEN
    NUEVO_ORIGEN=$(echo "$NUEVO_ORIGEN" | tr '[:upper:]' '[:lower:]' | xargs)

    if validar_dominio "$NUEVO_ORIGEN"; then
        break
    fi
done

# 🔁 Bucle principal: pedir dominio y confirmar
while true; do
    # Obtener IP del dominio
    IP_DOMINIO_NEW=$(getent hosts "$NUEVO_ORIGEN" | awk '{ print $1 }' | head -n 1)
[[ -z "$IP_DOMINIO_NEW" ]] && IP_DOMINIO_NEW="IP no encontrada"

    echo -e "${YELLOW}⚠️ Se cambiará el dominio de origen a: ${BOLD}${NUEVO_ORIGEN} (${IP_DOMINIO_NEW})${RESET}"

    read -p $'\e[1;93m¿Confirmar el cambio? (s/n): \e[0m' CONFIRMAR
    CONFIRMAR=$(echo "$CONFIRMAR" | tr '[:upper:]' '[:lower:]')

    if [[ "$CONFIRMAR" == "s" ]]; then
        echo -e "${BLUE}🔧 Actualizando configuración...${RESET}"
        # Aquí se realizaría la actualización con jq, por ejemplo:
        jq --arg newdomain "$NUEVO_ORIGEN" \
           '.Origins.Items[0].DomainName = $newdomain' \
           <<< "$CONFIG" > nueva_config.json
        break  # ✅ Sale del bucle, todo correcto

    elif [[ "$CONFIRMAR" == "n" ]]; then
        echo -e "${RED}🔁 Se repetirá la edición del dominio de origen.${RESET}"
        
        # Volver a pedir el nuevo dominio
        while true; do
            read -p $'\e[1;96m✏️ Ingrese su nuevo dominio de origen: \e[0m' NUEVO_ORIGEN
            NUEVO_ORIGEN=$(echo "$NUEVO_ORIGEN" | tr '[:upper:]' '[:lower:]' | xargs)
            if validar_dominio "$NUEVO_ORIGEN"; then
                break
            else
                echo -e "${RED}❌ Por favor, ingrese un dominio válido.${RESET}"
            fi
        done

    else
        echo -e "${RED}❌ Opción inválida. Solo se permite 's' o 'n'.${RESET}"
    fi
done

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

# Eliminar este script
rm -- "$0"
