#!/bin/bash

# ┌────────────────────────────────────────────────────────┐
# │ Instalación silenciosa como comando global 'aws-manager'         │
# └────────────────────────────────────────────────────────┘
if [[ "$0" != */aws-manager ]]; then
    SCRIPT_PATH="$HOME/.aws-manager.sh"
    curl -s https://raw.githubusercontent.com/ChristopherAGT/aws-cloudfront/main/manager-distribution.sh -o "$SCRIPT_PATH"
    chmod +x "$SCRIPT_PATH"
    mkdir -p "$HOME/.local/bin"
    ln -sf "$SCRIPT_PATH" "$HOME/.local/bin/aws-manager"
    export PATH="$HOME/.local/bin:$PATH"
fi

clear

# ╔══════════════════════════════════════════════════════════╗
# ║            🛠️ AWS CLOUDFRONT MANAGER - PANEL            ║
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

menu_header() {
    echo -e "${CYAN}"
    echo "╔════════════════════════════════════════════╗"
    echo "║          🛠️ AWS CLOUDFRONT MANAGER - PANEL         ║"
    echo "╚════════════════════════════════════════════╝"
    divider
}

menu() {
    clear
    menu_header
    echo -e "${BOLD}${CYAN}● Seleccione una opción:${RESET}"
    divider
    echo -e "${YELLOW}1.${RESET} 🆕 Crear distribución"
    echo -e "${YELLOW}2.${RESET} 📊 Ver estado de distribuciones"
    echo -e "${YELLOW}3.${RESET} ⚙️ Editar distribución"
    echo -e "${YELLOW}4.${RESET} 🔁 Activar/Desactivar distribución"
    echo -e "${YELLOW}5.${RESET} 🗑️ Eliminar distribución"
    echo -e "${YELLOW}6.${RESET} 🧹 Remover el panel"
    echo -e "${YELLOW}7.${RESET} 🚪 Salir"
    divider
}

pause() {
    read -rp $'\n\e[1;93m👉 Presiona ENTER para volver al menú... \e[0m'
}

# Función genérica para ejecutar scripts
ejecutar_script() {
    local url="$1"
    local archivo="$2"
    local mostrar_exito="$3"

    if wget -q "$url" -O "$archivo"; then
        bash "$archivo"
        local RET=$?
        rm -f "$archivo"
        if [ "$RET" -eq 0 ] && [ "$mostrar_exito" = true ]; then
            echo -e "${GREEN}✅ Script ejecutado correctamente.${RESET}"
        elif [ "$RET" -ne 0 ]; then
            echo -e "${RED}❌ El script terminó con errores (Código $RET).${RESET}"
        fi
    else
        echo -e "${RED}❌ No se pudo descargar el script: $archivo.${RESET}"
    fi
}

remover_panel() {
    echo -e "${YELLOW}🧹 Removiendo archivos instalados...${RESET}"
    rm -f "$HOME/.aws-manager.sh"
    rm -f "$HOME/.local/bin/aws-manager"
    echo -e "${GREEN}✅ Archivos eliminados correctamente.${RESET}"
}

while true; do
    menu
    read -rp $'\e[1;93m🔢 Ingrese opción (1-7): \e[0m' opcion

    case "$opcion" in
        1)
            echo -e "${BLUE}Ejecutando: Crear distribución...${RESET}"
            ejecutar_script "https://raw.githubusercontent.com/ChristopherAGT/aws-cloudfront/main/create-distribution.sh" "create-distribution.sh" true
            pause
            ;;
        2)
            echo -e "${BLUE}Ejecutando: Ver estado de distribuciones...${RESET}"
            ejecutar_script "https://raw.githubusercontent.com/ChristopherAGT/aws-cloudfront/main/status-distribution.sh" "status-distribution.sh" false
            pause
            ;;
        3)
            echo -e "${BLUE}Ejecutando: Editar distribución...${RESET}"
            ejecutar_script "https://raw.githubusercontent.com/ChristopherAGT/aws-cloudfront/main/edit-distribution.sh" "edit-distribution.sh" true
            pause
            ;;
        4)
            echo -e "${BLUE}Ejecutando: Activar/Desactivar distribución...${RESET}"
            ejecutar_script "https://raw.githubusercontent.com/ChristopherAGT/aws-cloudfront/main/control-status-distribution.sh" "control-status-distribution.sh" true
            pause
            ;;
        5)
            echo -e "${BLUE}Ejecutando: Eliminar distribución...${RESET}"
            ejecutar_script "https://raw.githubusercontent.com/ChristopherAGT/aws-cloudfront/main/delete-distribution.sh" "delete-distribution.sh" true
            pause
            ;;
        6)
            remover_panel
            #pause
            ;;
        7)
            echo -e "${MAGENTA}👋 Saliendo del panel...${RESET}"
            echo -e "${CYAN}💡 Puedes ejecutar nuevamente el panel con el comando: ${BOLD}aws-manager${RESET}"
            echo -e "${GREEN}📝 Créditos a 👾 Christopher Ackerman${RESET}"
            exit 0
            ;;
        *)
            echo -e "${RED}❌ Opción inválida. Por favor ingresa un número entre 1 y 7.${RESET}"
            pause
            ;;
    esac
done
