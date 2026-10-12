
#!/usr/bin/env bash

# ╔══════════════════════════════════════════════════════════════╗
# ║                 AWS CLOUDFRONT MANAGER                       ║
# ║                  Dashboard administrativo                    ║
# ╚══════════════════════════════════════════════════════════════╝

set -o pipefail

# ────────────────────────────────────────────────────────────────
# CONFIGURACIÓN
# ────────────────────────────────────────────────────────────────

REPO="https://raw.githubusercontent.com/ChristopherAGT/aws-cloudfront/main"
BIN_DIR="${HOME}/.local/bin"
BIN_PATH="${BIN_DIR}/aws-manager"
VERSION="v1.0"

# ────────────────────────────────────────────────────────────────
# COLORES ANSI
# ────────────────────────────────────────────────────────────────

if [[ -t 1 ]]; then
    R=$'\033[0m'
    B=$'\033[1m'
    D=$'\033[2m'
    RED=$'\033[1;31m'
    GREEN=$'\033[1;32m'
    YELLOW=$'\033[1;33m'
    BLUE=$'\033[1;34m'
    MAGENTA=$'\033[1;35m'
    CYAN=$'\033[1;36m'
    WHITE=$'\033[1;37m'
    GRAY=$'\033[0;37m'
else
    R='' B='' D='' RED='' GREEN='' YELLOW=''
    BLUE='' MAGENTA='' CYAN='' WHITE='' GRAY=''
fi

# ────────────────────────────────────────────────────────────────
# INSTALACIÓN COMO COMANDO GLOBAL
# ────────────────────────────────────────────────────────────────

install_manager() {
    local source_path

    source_path="$(readlink -f -- "$0" 2>/dev/null || printf '%s' "$0")"

    if [[ "$source_path" == "$BIN_PATH" ]]; then
        return 0
    fi

    mkdir -p "$BIN_DIR" || {
        printf '%b\n' "${RED}✖ No se pudo crear ${BIN_DIR}.${R}"
        exit 1
    }

    if ! cp -- "$source_path" "$BIN_PATH"; then
        printf '%b\n' "${RED}✖ No se pudo instalar aws-manager.${R}"
        exit 1
    fi

    chmod 700 "$BIN_PATH" || {
        printf '%b\n' "${RED}✖ No se pudieron establecer los permisos.${R}"
        exit 1
    }

    case ":${PATH}:" in
        *":${BIN_DIR}:"*) ;;
        *) export PATH="${BIN_DIR}:${PATH}" ;;
    esac

    printf '\n%b\n' "${GREEN}✔ AWS Manager instalado correctamente.${R}"
    printf '%b\n\n' "${GRAY}Comando: aws-manager${R}"

    exec "$BIN_PATH" "$@"
}

install_manager "$@"

# ────────────────────────────────────────────────────────────────
# DEPENDENCIAS
# ────────────────────────────────────────────────────────────────

check_dependencies() {
    local missing=()

    command -v curl >/dev/null 2>&1 || missing+=("curl")
    command -v bash >/dev/null 2>&1 || missing+=("bash")

    if ((${#missing[@]} > 0)); then
        printf '%b\n' "${RED}✖ Faltan dependencias: ${missing[*]}${R}"
        printf '%b\n' "${YELLOW}Instálalas con el gestor de paquetes.${R}"
        exit 1
    fi
}

# ────────────────────────────────────────────────────────────────
# UTILIDADES VISUALES
# ────────────────────────────────────────────────────────────────

pause() {
    printf '\n'
    read -r -p "$(printf '%b' "${GRAY}Presiona ENTER para continuar...${R}")" _
}

line() {
    printf '%b\n' \
        "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${R}"
}

# ────────────────────────────────────────────────────────────────
# ENCABEZADO
# ────────────────────────────────────────────────────────────────

header() {
    clear 2>/dev/null || true

    printf '\n'
    printf '%b\n' "${CYAN}  ╭────────────────────────────────────────────────────────╮${R}"
    printf '%b\n' "${CYAN}  │                                                        │${R}"
    printf '%b\n' "${CYAN}  │${R}       ${WHITE}${B}☁ AWS CLOUDFRONT MANAGER${R}                 ${CYAN}│${R}"
    printf '%b\n' "${CYAN}  │${R}       ${GRAY}DASHBOARD DE ADMINISTRACIÓN${R}             ${CYAN}│${R}"
    printf '%b\n' "${CYAN}  │                                                        │${R}"
    printf '%b\n' "${CYAN}  ╰────────────────────────────────────────────────────────╯${R}"
    printf '\n'
}

# ────────────────────────────────────────────────────────────────
# BARRA DE ESTADO
# ────────────────────────────────────────────────────────────────

status_bar() {
    printf '%b\n' "${GRAY}  ┌────────────────────────────────────────────────────────┐${R}"
    printf '%b\n' "${GRAY}  │${R} ${GREEN}✔ Panel listo${R}                                  ${YELLOW}${VERSION}${R} ${GRAY}│${R}"
    printf '%b\n' "${GRAY}  └────────────────────────────────────────────────────────┘${R}"
}

# ────────────────────────────────────────────────────────────────
# TÍTULOS DE SECCIÓN
# ────────────────────────────────────────────────────────────────

section_title() {
    printf '\n'
    printf '%b\n' "${BLUE}${B}  ◈ $1${R}"
}

# ────────────────────────────────────────────────────────────────
# TARJETAS DEL DASHBOARD
# Dos columnas por dos filas.
# Cada tarjeta utiliza el mismo ancho.
# ────────────────────────────────────────────────────────────────

dashboard_cards() {
    # Fila 1: bordes superiores
    printf '%b\n' \
        "${BLUE}  ┌──────────────────────────┐${R} ${GREEN}┌──────────────────────────┐${R}"

    # Fila 1: títulos
    printf '%b\n' \
        "${BLUE}  │${R} ☁ ${BLUE}Distribuciones${R}           ${BLUE}│${R} ${GREEN}│${R} 🟢 ${GREEN}Habilitadas${R}              ${GREEN}│${R}"

    # Fila 1: valores
    printf '%b\n' \
        "${BLUE}  │${R} ${WHITE}${B}Sin consultar${R}             ${BLUE}│${R} ${GREEN}│${R} ${WHITE}${B}Sin consultar${R}             ${GREEN}│${R}"

    # Fila 1: bordes inferiores
    printf '%b\n' \
        "${BLUE}  └──────────────────────────┘${R} ${GREEN}└──────────────────────────┘${R}"

    printf '\n'

    # Fila 2: bordes superiores
    printf '%b\n' \
        "${YELLOW}  ┌──────────────────────────┐${R} ${MAGENTA}┌──────────────────────────┐${R}"

    # Fila 2: títulos
    printf '%b\n' \
        "${YELLOW}  │${R} 🟡 ${YELLOW}Deshabilitadas${R}          ${YELLOW}│${R} ${MAGENTA}│${R} 🔐 ${MAGENTA}Certificados SSL${R}        ${MAGENTA}│${R}"

    # Fila 2: valores
    printf '%b\n' \
        "${YELLOW}  │${R} ${WHITE}${B}Sin consultar${R}             ${YELLOW}│${R} ${MAGENTA}│${R} ${WHITE}${B}Sin consultar${R}             ${MAGENTA}│${R}"

    # Fila 2: bordes inferiores
    printf '%b\n' \
        "${YELLOW}  └──────────────────────────┘${R} ${MAGENTA}└──────────────────────────┘${R}"

    printf '\n'
    printf '%b\n' \
        "${GRAY}  ℹ Las estadísticas requieren una consulta real a AWS.${R}"
}

# ────────────────────────────────────────────────────────────────
# MENÚ PRINCIPAL VISUAL
# ────────────────────────────────────────────────────────────────

dashboard() {
    header

    status_bar

    section_title "RESUMEN DEL SISTEMA"

    dashboard_cards

    printf '\n'
    printf '%b\n' \
        "${CYAN}  ──────────────────────────────────────────────────────────${R}"

    section_title "CENTRO DE CONTROL"

    printf '%b\n' \
        "${CYAN}  ╭────────────────────────────────────────────────────────╮${R}"

    printf '%b\n' \
        "${CYAN}  │${R} ${YELLOW}[1]${R}  🚀 Crear distribución                         ${CYAN}│${R}"
    printf '%b\n' \
        "${CYAN}  │${R} ${YELLOW}[2]${R}  📊 Ver estado de distribuciones               ${CYAN}│${R}"
    printf '%b\n' \
        "${CYAN}  │${R} ${YELLOW}[3]${R}  ⚙️  Editar distribución                       ${CYAN}│${R}"
    printf '%b\n' \
        "${CYAN}  │${R} ${YELLOW}[4]${R}  🔄 Activar / Desactivar distribución          ${CYAN}│${R}"
    printf '%b\n' \
        "${CYAN}  │${R} ${YELLOW}[5]${R}  🗑️  Eliminar distribución                     ${CYAN}│${R}"

    printf '%b\n' \
        "${CYAN}  │                                                        │${R}"
    printf '%b\n' \
        "${CYAN}  ├────────────────────────────────────────────────────────┤${R}"
    printf '%b\n' \
        "${CYAN}  │                                                        │${R}"

    printf '%b\n' \
        "${CYAN}  │${R} ${YELLOW}[6]${R}  🔐 Crear certificado SSL                      ${CYAN}│${R}"
    printf '%b\n' \
        "${CYAN}  │${R} ${YELLOW}[7]${R}  🧹 Remover el panel                           ${CYAN}│${R}"
    printf '%b\n' \
        "${CYAN}  │${R} ${YELLOW}[8]${R}  🚪 Salir                                     ${CYAN}│${R}"

    printf '%b\n' \
        "${CYAN}  ╰────────────────────────────────────────────────────────╯${R}"

    printf '\n'
    printf '%b\n' \
        "${GRAY}  AWS CloudFront · Administración · Seguridad SSL${R}"

    printf '\n'
    printf '%b' "${CYAN}${B}  ❯ Selecciona una opción [1-8]: ${R}"
}

# ────────────────────────────────────────────────────────────────
# EJECUCIÓN SEGURA DE MÓDULOS REMOTOS
# ────────────────────────────────────────────────────────────────

run_module() {
    local module="$1"
    local url="${REPO}/${module}"
    local tmp_file
    local result

    tmp_file="$(mktemp 2>/dev/null)" || {
        printf '%b\n' "${RED}✖ No se pudo crear un archivo temporal.${R}"
        pause
        return 1
    }

    printf '\n'
    printf '%b\n' \
        "${CYAN}⟳ Descargando módulo: ${WHITE}${module}${R}"

    if ! curl -fsSL \
        --connect-timeout 10 \
        --max-time 120 \
        "$url" -o "$tmp_file"; then

        printf '%b\n' "${RED}✖ No se pudo descargar el módulo.${R}"
        printf '%b\n' \
            "${GRAY}Verifica la conexión y que el archivo exista en GitHub.${R}"

        rm -f -- "$tmp_file"
        pause
        return 1
    fi

    if [[ ! -s "$tmp_file" ]]; then
        printf '%b\n' "${RED}✖ El módulo descargado está vacío.${R}"
        rm -f -- "$tmp_file"
        pause
        return 1
    fi

    if ! bash -n "$tmp_file"; then
        printf '%b\n' "${RED}✖ El módulo contiene errores de sintaxis Bash.${R}"
        rm -f -- "$tmp_file"
        pause
        return 1
    fi

    printf '%b\n' "${GREEN}✔ Módulo verificado. Iniciando...${R}"
    printf '\n'

    bash "$tmp_file"
    result=$?

    rm -f -- "$tmp_file"

    if ((result != 0)); then
        printf '\n%b\n' \
            "${YELLOW}⚠ El módulo terminó con código ${result}.${R}"
    fi

    pause
    return "$result"
}

# ────────────────────────────────────────────────────────────────
# DESINSTALACIÓN DEL PANEL
# ────────────────────────────────────────────────────────────────

uninstall_manager() {
    printf '\n'
    printf '%b\n' "${YELLOW}${B}⚠ DESINSTALACIÓN DEL PANEL${R}"
    printf '%b\n' \
        "${GRAY}Se eliminará el comando local aws-manager.${R}"
    printf '%b\n' \
        "${GRAY}No se borrarán distribuciones ni certificados de AWS.${R}"
    printf '\n'

    read -r -p \
        "$(printf '%b' "${WHITE}¿Deseas continuar? [s/N]: ${R}")" confirm

    case "$confirm" in
        s|S|si|SI|Si|sí|Sí|SÍ)
            rm -f -- "$BIN_PATH"

            printf '\n%b\n' \
                "${GREEN}✔ Comando aws-manager eliminado.${R}"
            printf '%b\n' \
                "${GRAY}Los recursos de AWS permanecen intactos.${R}"
            exit 0
            ;;
        *)
            printf '\n%b\n' "${GRAY}Desinstalación cancelada.${R}"
            pause
            ;;
    esac
}

# ────────────────────────────────────────────────────────────────
# MENÚ PRINCIPAL Y CONTROL DE OPCIONES
# ────────────────────────────────────────────────────────────────

main() {
    local option
    local confirm

    check_dependencies

    while true; do
        dashboard

        if ! read -r option; then
            printf '\n%b\n' "${GRAY}Entrada cerrada. Saliendo.${R}"
            exit 0
        fi

        case "$option" in
            1)
                run_module "create-distribution.sh"
                ;;

            2)
                run_module "status-distribution.sh"
                ;;

            3)
                run_module "edit-distribution.sh"
                ;;

            4)
                run_module "control-status-distribution.sh"
                ;;

            5)
                printf '\n%b\n' \
                    "${RED}${B}⚠ ATENCIÓN: ELIMINAR DISTRIBUCIÓN${R}"

                read -r -p \
                    "$(printf '%b' "${YELLOW}¿Continuar con el módulo de eliminación? [s/N]: ${R}")" \
                    confirm

                case "$confirm" in
                    s|S|si|SI|Si|sí|Sí|SÍ)
                        run_module "delete-distribution.sh"
                        ;;
                    *)
                        printf '%b\n' "${GRAY}Operación cancelada.${R}"
                        pause
                        ;;
                esac
                ;;

            6)
                run_module "create-certificate.sh"
                ;;

            7)
                uninstall_manager
                ;;

            8)
                printf '\n'
                printf '%b\n' \
                    "${CYAN}  ╭────────────────────────────────────────────────────────╮${R}"
                printf '%b\n' \
                    "${CYAN}  │${R}       ${GREEN}${B}✔ Gracias por utilizar AWS Manager${R}          ${CYAN}│${R}"
                printf '%b\n' \
                    "${CYAN}  │${R}                   ${GRAY}Hasta pronto.${R}                     ${CYAN}│${R}"
                printf '%b\n' \
                    "${CYAN}  ╰────────────────────────────────────────────────────────╯${R}"
                printf '\n'
                exit 0
                ;;

            *)
                printf '\n%b\n' \
                    "${RED}✖ Opción inválida. Selecciona del 1 al 8.${R}"
                sleep 1
                ;;
        esac
    done
}

main "$@"
