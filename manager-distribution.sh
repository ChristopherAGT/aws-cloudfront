#!/bin/bash

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
    echo "╔═════════════════════════════════════════════╗"
    echo "║        🛠️ AWS CLOUDFRONT MANAGER - PANEL            ║"
    echo "╚═════════════════════════════════════════════╝"
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
    echo -e "${YELLOW}6.${RESET} 🚪 Salir"
    divider
}

pause() {
    read -rp $'\n\e[1;93m👉 Presiona ENTER para volver al menú... \e[0m'
}

# Función para instalar el script como comando global
install_command() {
    SCRIPT_PATH="$HOME/.aws-cloudfront-manager.sh"
    echo -e "${BLUE}Instalando comando global 'aws-manager'...${RESET}"

    # Descargar el script completo y guardarlo en el HOME
    curl -s https://raw.githubusercontent.com/ChristopherAGT/aws-cloudfront/main/manager-distribution.sh -o "$SCRIPT_PATH"
    if [ $? -ne 0 ]; then
        echo -e "${RED}❌ Error descargando el script. Instalación abortada.${RESET}"
        exit 1
    fi
    chmod +x "$SCRIPT_PATH"

    # Crear enlace simbólico en /usr/local/bin o ~/.local/bin
    if [ -w "/usr/local/bin" ]; then
        ln -sf "$SCRIPT_PATH" /usr/local/bin/aws-manager
        echo -e "${GREEN}✅ Comando 'aws-manager' instalado en /usr/local/bin.${RESET}"
    else
        # Crear ~/.local/bin si no existe
        mkdir -p "$HOME/.local/bin"
        ln -sf "$SCRIPT_PATH" "$HOME/.local/bin/aws-manager"
        echo -e "${YELLOW}⚠️ No se pudo instalar en /usr/local/bin."
        echo -e "Se instaló en ~/.local/bin/aws-manager. Asegúrate de tener esta ruta en tu PATH.${RESET}"
    fi

    echo -e "${GREEN}✅ Instalación completa. Ejecuta 'aws-manager' para abrir el panel.${RESET}"
}

# Si se ejecuta con argumento 'install', instalar y salir
if [[ "$1" == "install" ]]; then
    install_command
    exit 0
fi

while true; do
    menu
    read -rp $'\e[1;93m🔢 Ingrese opción (1-6): \e[0m' opcion

    case "$opcion" in
        1)
            echo -e "${BLUE}Ejecutando: Crear distribución...${RESET}"
            if wget -q https://raw.githubusercontent.com/ChristopherAGT/aws-cloudfront/main/create-distribution.sh -O create-distribution.sh; then
                bash create-distribution.sh
                RET=$?
                rm -f create-distribution.sh
                if [ $RET -eq 0 ]; then
                    echo -e "${GREEN}✅ Script ejecutado correctamente.${RESET}"
                else
                    echo -e "${RED}❌ El script terminó con errores (Código $RET).${RESET}"
                fi
            else
                echo -e "${RED}❌ No se pudo descargar el script de creación.${RESET}"
            fi
            pause
            ;;
        2)
            echo -e "${BLUE}Ejecutando: Ver estado de distribuciones...${RESET}"
            if wget -q https://raw.githubusercontent.com/ChristopherAGT/aws-cloudfront/main/status-distribution.sh -O status-distribution.sh; then
                bash status-distribution.sh
                RET=$?
                rm -f status-distribution.sh
                if [ $RET -eq 0 ]; then
                    echo -e "${GREEN}✅ Script ejecutado correctamente.${RESET}"
                else
                    echo -e "${RED}❌ El script terminó con errores (Código $RET).${RESET}"
                fi
            else
                echo -e "${RED}❌ No se pudo descargar el script de estado.${RESET}"
            fi
            pause
            ;;
        3)
            echo -e "${BLUE}Ejecutando: Editar distribución...${RESET}"
            if wget -q https://raw.githubusercontent.com/ChristopherAGT/aws-cloudfront/main/edit-distribution.sh -O edit-distribution.sh; then
                bash edit-distribution.sh
                RET=$?
                rm -f edit-distribution.sh
                if [ $RET -eq 0 ]; then
                    echo -e "${GREEN}✅ Script ejecutado correctamente.${RESET}"
                else
                    echo -e "${RED}❌ El script terminó con errores (Código $RET).${RESET}"
                fi
            else
                echo -e "${RED}❌ No se pudo descargar el script de edición.${RESET}"
            fi
            pause
            ;;
        4)
            echo -e "${BLUE}Ejecutando: Activar/Desactivar distribución...${RESET}"
            if wget -q https://raw.githubusercontent.com/ChristopherAGT/aws-cloudfront/main/control-status-distribution.sh -O control-status-distribution.sh; then
                bash control-status-distribution.sh
                RET=$?
                rm -f control-status-distribution.sh
                if [ $RET -eq 0 ]; then
                    echo -e "${GREEN}✅ Script ejecutado correctamente.${RESET}"
                else
                    echo -e "${RED}❌ El script terminó con errores (Código $RET).${RESET}"
                fi
            else
                echo -e "${RED}❌ No se pudo descargar el script de control de estado.${RESET}"
            fi
            pause
            ;;
        5)
            echo -e "${BLUE}Ejecutando: Eliminar distribución...${RESET}"
            if wget -q https://raw.githubusercontent.com/ChristopherAGT/aws-cloudfront/main/delete-distribution.sh -O delete-distribution.sh; then
                bash delete-distribution.sh
                RET=$?
                rm -f delete-distribution.sh
                if [ $RET -eq 0 ]; then
                    echo -e "${GREEN}✅ Script ejecutado correctamente.${RESET}"
                else
                    echo -e "${RED}❌ El script terminó con errores (Código $RET).${RESET}"
                fi
            else
                echo -e "${RED}❌ No se pudo descargar el script de eliminación.${RESET}"
            fi
            pause
            ;;
        6)
            echo -e "${MAGENTA}👋 Saliendo del panel...${RESET}"
            echo -e "${CYAN}💡 Puedes ejecutar nuevamente el panel con el comando: ${BOLD}aws-manager${RESET}"
            echo -e "${GREEN}📝 Créditos a 👾 Christopher Ackerman${RESET}"
            exit 0
            ;;
        *)
            echo -e "${RED}❌ Opción inválida. Por favor ingresa un número entre 1 y 6.${RESET}"
            pause
            ;;
    esac
done
