
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

# ────────────────────────────────────────────────────────────────
# COLORES
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
# INSTALACIÓN COMO COMANDO GLOBAL DEL USUARIO
# ────────────────────────────────────────────────────────────────

install_manager() {
    local source_path

    source_path="$(readlink -f -- "$0" 2>/dev/null || printf '%s' "$0")"

    # Si ya se ejecuta desde la ruta de instalación, continuar.
    if [[ "$0" == "$BIN_PATH" ]]; then
        return 0
    fi

    # Evitar reinstalar recursivamente cuando el archivo ya está instalado.
    if [[ "$source_path" == "$BIN_PATH" ]]; then
        return 0
    fi

    mkdir -p "$BIN_DIR" || {
        printf '%b\n' "${RED}✖ No se pudo crear el directorio ${BIN_DIR}.${R}"
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
        *)
            export PATH="${BIN_DIR}:${PATH}"
            ;;
    esac

    printf '\n%b\n' "${GREEN}✔ AWS Manager instalado correctamente.${R}"
    printf '%b\n\n' "${GRAY}Comando: aws-manager${R}"

    exec "$BIN_PATH" "$@"
}

install_manager

# ────────────────────────────────────────────────────────────────
# DEPENDENCIAS
# ────────────────────────────────────────────────────────────────

check_dependencies() {
    local missing=()

    command -v curl >/dev/null 2>&1 || missing+=("curl")
    command -v bash >/dev/null 2>&1 || missing+=("bash")

    if ((${#missing[@]} > 0)); then
        printf '%b\n' "${RED}✖ Faltan dependencias: ${missing[*]}${R}"
        printf '%b\n' "${YELLOW}Instálalas con el gestor de paquetes de tu sistema.${R}"
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
    printf '%b\n' "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${R}"
}

header() {
    clear 2>/dev/null || true

    printf '\n'
    printf '%b\n' "${CYAN}╔══════════════════════════════════════════════════════════════╗${R}"
    printf '%b\n' "${CYAN}║${R}                                                              ${CYAN}║${R}"
    printf '%b\n' "${CYAN}║${R}  ${WHITE}${B}       ▄▀▀ █   █ ▄▀▀   █▀▀ █   █ █▀▀ █▀▀ █▀▀ █▀▀${R}       ${CYAN}║${R}"
    printf '%b\n' "${CYAN}║${R}  ${WHITE}${B}       ▀▄▄ █▄▄▄█ ▄▄▀   █   █▄▄▄█ █▀▀ ▀▀█ █   █▀▀${R}       ${CYAN}║${R}"
    printf '%b\n' "${CYAN}║${R}  ${WHITE}${B}       ▄▄▀ █   █ ▀▄▄   ▀▀▀ █   █ █▄▄ ▄▄█ █▄▄ █▄▄${R}       ${CYAN}║${R}"
    printf '%b\n' "${CYAN}║${R}                                                              ${CYAN}║${R}"
    printf '%b\n' "${CYAN}║${R}              ${B}${MAGENTA}C L O U D F R O N T   M A N A G E R${R}             ${CYAN}║${R}"
    printf '%b\n' "${CYAN}║${R}                  ${GRAY}PANEL DE ADMINISTRACIÓN${R}                     ${CYAN}║${R}"
    printf '%b\n' "${CYAN}║${R}                                                              ${CYAN}║${R}"
    printf '%b\n' "${CYAN}╚══════════════════════════════════════════════════════════════╝${R}"
    printf '\n'
}

section() {
    printf '\n%b\n' "${CYAN}┌─ ${WHITE}${B}$1${R}${CYAN} ─────────────────────────────────────────────────────┐${R}"
}

section_end() {
    printf '%b\n' "${CYAN}└──────────────────────────────────────────────────────────────┘${R}"
}

# ────────────────────────────────────────────────────────────────
# TARJETAS DEL DASHBOARD
# ────────────────────────────────────────────────────────────────

stat_card() {
    local title="$1"
    local value="$2"
    local description="$3"
    local color="$4"

    printf '%b\n' "${CYAN}┌──────────────────────────────────────────────────────────────┐${R}"
    printf '%b\n' "${CYAN}│${R}  ${GRAY}${title}${R}"
    printf '%b\n' "${CYAN}│${R}"
    printf '%b\n' "${CYAN}│${R}  ${color}${B}${value}${R}"
    printf '%b\n' "${CYAN}│${R}  ${GRAY}${description}${R}"
    printf '%b\n' "${CYAN}└──────────────────────────────────────────────────────────────┘${R}"
}

dashboard() {
    header

    printf '%b\n' "${WHITE}${B}  DASHBOARD DE ADMINISTRACIÓN${R}"
    printf '%b\n' "${GRAY}  Centro de control de distribuciones y certificados AWS${R}"

    printf '\n'
    stat_card "DISTRIBUCIONES CLOUDFRONT" "● GESTIÓN DISPONIBLE" \
        "Crear, consultar, editar y eliminar" "$CYAN"

    stat_card "ESTADO DEL SERVICIO" "● PANEL ACTIVO" \
        "Interfaz de administración local" "$GREEN"

    stat_card "CERTIFICADOS SSL/TLS" "● GESTIÓN DISPONIBLE" \
        "Crear y administrar certificados" "$MAGENTA"

    stat_card "CONSULTA AWS" "○ NO CONSULTADA" \
        "Los datos reales se obtienen al ejecutar una opción" "$YELLOW"

    section "MENÚ PRINCIPAL"

    printf '%b\n' "${CYAN}│${R}  ${CYAN}[${WHITE}1${CYAN}]${R}  ${WHITE}Crear distribución${R}"
    printf '%b\n' "${CYAN}│${R}  ${CYAN}[${WHITE}2${CYAN}]${R}  ${WHITE}Consultar estado de distribución${R}"
    printf '%b\n' "${CYAN}│${R}  ${CYAN}[${WHITE}3${CYAN}]${R}  ${WHITE}Editar distribución${R}"
    printf '%b\n' "${CYAN}│${R}  ${CYAN}[${WHITE}4${CYAN}]${R}  ${WHITE}Controlar estado de distribución${R}"
    printf '%b\n' "${CYAN}│${R}  ${CYAN}[${WHITE}5${CYAN}]${R}  ${RED}Eliminar distribución${R}"
    printf '%b\n' "${CYAN}│${R}  ${CYAN}[${WHITE}6${CYAN}]${R}  ${WHITE}Crear certificado SSL/TLS${R}"
    printf '%b\n' "${CYAN}│${R}  ${CYAN}[${WHITE}7${CYAN}]${R}  ${YELLOW}Desinstalar panel${R}"
    printf '%b\n' "${CYAN}│${R}  ${CYAN}[${WHITE}8${CYAN}]${R}  ${GRAY}Salir${R}"

    section_end

    printf '\n'
    printf '%b\n' "${GRAY}  Repositorio: ChristopherAGT/aws-cloudfront${R}"
    line
}

# ────────────────────────────────────────────────────────────────
# EJECUCIÓN DE MÓDULOS REMOTOS
# ────────────────────────────────────────────────────────────────

run_module() {
    local module="$1"
    local url="${REPO}/${module}"
    local tmp_file

    tmp_file="$(mktemp 2>/dev/null)" || {
        printf '%b\n' "${RED}✖ No se pudo crear un archivo temporal.${R}"
        pause
        return 1
    }

    printf '\n'
    printf '%b\n' "${CYAN}⟳ Descargando módulo: ${WHITE}${module}${R}"

    if ! curl -fsSL --connect-timeout 10 --max-time 120 \
        "$url" -o "$tmp_file"; then
        printf '%b\n' "${RED}✖ No se pudo descargar el módulo.${R}"
        printf '%b\n' "${GRAY}Verifica la conexión y que el archivo exista en GitHub.${R}"
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

    printf '%b\n' "${GREEN}✔ Módulo descargado. Iniciando...${R}"
    printf '\n'

    bash "$tmp_file"
    local result=$?

    rm -f -- "$tmp_file"

    if ((result != 0)); then
        printf '\n%b\n' "${YELLOW}⚠ El módulo terminó con código ${result}.${R}"
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
    printf '%b\n' "${GRAY}Esta acción elimina el comando local aws-manager.${R}"
    printf '%b\n' "${GRAY}No elimina por sí sola los recursos creados en AWS.${R}"
    printf '\n'

    read -r -p "$(printf '%b' "${WHITE}¿Deseas continuar? [s/N]: ${R}")" confirm

    case "$confirm" in
        s|S|si|SI|Si|sí|Sí)
            if [[ "$0" == "$BIN_PATH" ]]; then
                rm -f -- "$BIN_PATH"
            else
                rm -f -- "$BIN_PATH"
            fi

            printf '\n%b\n' "${GREEN}✔ Comando aws-manager eliminado.${R}"
            printf '%b\n' "${GRAY}Los módulos y recursos de AWS no se han eliminado automáticamente.${R}"
            exit 0
            ;;
        *)
            printf '\n%b\n' "${GRAY}Desinstalación cancelada.${R}"
            pause
            ;;
    esac
}

# ────────────────────────────────────────────────────────────────
# MENÚ PRINCIPAL
# ────────────────────────────────────────────────────────────────

main() {
    check_dependencies

    while true; do
        dashboard

        read -r -p "$(printf '%b' "${CYAN}  AWS-MANAGER ${WHITE}» ${R}")" option

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
                printf '\n%b\n' "${RED}${B}⚠ ATENCIÓN: ELIMINAR DISTRIBUCIÓN${R}"
                read -r -p "$(printf '%b' "${YELLOW}¿Continuar con el módulo de eliminación? [s/N]: ${R}")" confirm

                case "$confirm" in
                    s|S|si|SI|Si|sí|Sí)
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
                printf '\n%b\n' "${CYAN}╔══════════════════════════════════════════════════════════════╗${R}"
                printf '%b\n' "${CYAN}║${R}          ${GREEN}${B}✔ Gracias por utilizar AWS Manager${R}                 ${CYAN}║${R}"
                printf '%b\n' "${CYAN}║${R}                  ${GRAY}Hasta pronto.${R}                              ${CYAN}║${R}"
                printf '%b\n' "${CYAN}╚══════════════════════════════════════════════════════════════╝${R}"
                printf '\n'
                exit 0
                ;;
            *)
                printf '\n%b\n' "${RED}✖ Opción inválida. Selecciona un número del 1 al 8.${R}"
                sleep 1
                ;;
        esac
    done
}

main "$@"
