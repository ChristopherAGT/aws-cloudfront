#!/bin/bash

# ╔════════════════════════════════════════════════════════════╗
# ║         📦 PANEL INTERACTIVO - GESTOR CLOUDFRONT           ║
# ╚════════════════════════════════════════════════════════════╝

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

volver_al_menu() {
    echo ""
    read -p $'\e[1;93m📍 Presione ENTER para volver al menú...\e[0m'
}

ejecutar_comando() {
    local url=$1
    local archivo=$2

    echo -e "${CYAN}🔽 Descargando ${archivo}...${RESET}"
    if wget -q "$url" -O "$archivo"; then
        echo -e "${BLUE}🚀 Ejecutando ${archivo}...${RESET}"
        if bash "$archivo"; then
            echo -e "${GREEN}✅ Operación completada exitosamente.${RESET}"
        else
            echo -e "${RED}❌ Ocurrió un error al ejecutar el script.${RESET}"
        fi
        rm -f "$archivo"
    else
        echo -e "${RED}❌ Error al descargar el script.${RESET}"
    fi

    volver_al_menu
}

# 🔁 Bucle principal del menú
while true; do
    clear
    echo -e "${CYAN}"
    echo "╔════════════════════════════════════════════════════════════╗"
    echo "║         📦 PANEL INTERACTIVO - GESTOR CLOUDFRONT           ║"
    echo "╚════════════════════════════════════════════════════════════╝"
    echo -e "${RESET}"
    echo -e "${BOLD}${YELLOW}Seleccione una opción:${RESET}"
    divider
    echo -e "${BOLD}${CYAN}1) 🚀 Crear nueva distribución"
    echo -e "2) 🔎 Ver disponibilidad de distribuciones"
    echo -e "3) ❌ Eliminar distribución"
    echo -e "4) 🛠️ Editar distribución"
    echo -e "5) 🔁 Activar o desactivar distribución"
    echo -e "0) 🚪 Salir${RESET}"
    divider

    read -p $'\e[1;93m📥 Opción seleccionada: \e[0m' OPCION
    case $OPCION in
        1)
            ejecutar_comando \
              "https://raw.githubusercontent.com/ChristopherAGT/aws-cloudfront/main/create-distribution.sh" \
              "create-distribution.sh"
            ;;
        2)
            ejecutar_comando \
              "https://raw.githubusercontent.com/ChristopherAGT/aws-cloudfront/main/status-distribution.sh" \
              "status-distribution.sh"
            ;;
        3)
            ejecutar_comando \
              "https://raw.githubusercontent.com/ChristopherAGT/aws-cloudfront/main/delete-distribution.sh" \
              "delete-distribution.sh"
            ;;
        4)
            ejecutar_comando \
              "https://raw.githubusercontent.com/ChristopherAGT/aws-cloudfront/main/edit-distribution.sh" \
              "edit-distribution.sh"
            ;;
        5)
            ejecutar_comando \
              "https://raw.githubusercontent.com/ChristopherAGT/aws-cloudfront/main/control-status-distribution.sh" \
              "control-status-distribution.sh"
            ;;
        0)
            echo -e "${MAGENTA}👋 Saliendo del panel. ¡Hasta pronto!${RESET}"
            exit 0
            ;;
        *)
            echo -e "${RED}❌ Opción inválida. Intente nuevamente.${RESET}"
            sleep 2
            ;;
    esac
done
