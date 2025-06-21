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

pause() {
    read -rp $'\n\e[1;93m👉 Presiona ENTER para volver al menú... \e[0m'
}

menu() {
    clear
    echo -e "${CYAN}"
    echo "╔════════════════════════════════════════════════╗"
    echo "║           🛠️ AWS CLOUDFRONT MANAGER - PANEL             ║"
    echo "╚════════════════════════════════════════════════╝"
    divider
    echo -e "${BOLD}${CYAN} ⬇️ Seleccione una opción:${RESET}"
    echo -e "${YELLOW}1.${RESET} 🆕 Crear distribución"
    echo -e "${YELLOW}2.${RESET} 📊 Ver estado de distribuciones"
    echo -e "${YELLOW}3.${RESET} ⚙️ Editar distribución"
    echo -e "${YELLOW}4.${RESET} 🔁 Activar/Desactivar distribución"
    echo -e "${YELLOW}5.${RESET} 🗑️ Eliminar distribución"
    echo -e "${YELLOW}6.${RESET} 🚪 Salir"
    divider
}

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
            echo -e "${MAGENTA}👋 Saliendo del panel. ¡Hasta luego!${RESET}"
            exit 0
            ;;
        *)
            echo -e "${RED}❌ Opción inválida. Por favor ingrese un número entre 1 y 6.${RESET}"
            pause
            ;;
    esac
done
