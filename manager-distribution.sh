
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

# Anchos fijos de los cuadros.
# BOX_INNER incluye los espacios entre los bordes verticales.
BOX_INNER=54
CARD_INNER=24
CARD_GAP=2

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
# UTILIDADES PARA MEDIR TEXTO Y DIBUJAR BORDES
# ────────────────────────────────────────────────────────────────

# Calcula el ancho visible sin contar los códigos ANSI.
# wc -L considera el ancho de las columnas de la terminal.
visible_width() {
    local value="$1"
    local width

    width="$(
        printf '%s' "$value" |
            LC_ALL="${LC_ALL:-C.UTF-8}" sed -E \
                $'s/\033\\[[0-9;]*[[:alpha:]]//g' |
            wc -L
    )" || width=0

    width="${width//[[:space:]]/}"
    printf '%s' "${width:-0}"
}

# Genera una línea horizontal de ancho exacto.
repeat_char() {
    local char="$1"
    local count="$2"
    local result=""

    ((count < 0)) && count=0

    while ((count > 0)); do
        result+="$char"
        ((count--))
    done

    printf '%s' "$result"
}

# Rellena el contenido para que la caja conserve siempre
# exactamente el mismo ancho, independientemente del texto.
box_row() {
    local color="$1"
    local content="$2"
    local width
    local padding

    width="$(visible_width "$content")"
    padding=$((BOX_INNER - width - 2))

    ((padding < 0)) && padding=0

    printf '%b│%b %b%*s %b│%b\n' \
        "$color" "$R" \
        "$content" "$padding" "" \
        "$color" "$R"
}

# Borde superior e inferior de una caja grande.
box_top() {
    local color="$1"
    local horizontal

    horizontal="$(repeat_char '─' "$BOX_INNER")"

    printf '%b  ╭%s╮%b\n' "$color" "$horizontal" "$R"
}

box_bottom() {
    local color="$1"
    local horizontal

    horizontal="$(repeat_char '─' "$BOX_INNER")"

    printf '%b  ╰%s╯%b\n' "$color" "$horizontal" "$R"
}

# Separador horizontal dentro de una caja.
box_separator() {
    local color="$1"
    local horizontal

    horizontal="$(repeat_char '─' "$BOX_INNER")"

    printf '%b  ├%s┤%b\n' "$color" "$horizontal" "$R"
}

# Texto centrado dentro del ancho establecido.
center_text() {
    local text="$1"
    local total="$2"
    local width
    local left
    local right

    width="$(visible_width "$text")"

    if ((width >= total)); then
        printf '%s' "$text"
        return
    fi

    left=$(((total - width) / 2))
    right=$((total - width - left))

    printf '%*s%b%*s' "$left" "" "$text" "$right" ""
}

# Línea exterior de una tarjeta pequeña.
card_border() {
    local color="$1"
    local side="$2"
    local horizontal

    horizontal="$(repeat_char '─' "$CARD_INNER")"

    case "$side" in
        top)
            printf '%b┌%s┐%b' "$color" "$horizontal" "$R"
            ;;
        bottom)
            printf '%b└%s┘%b' "$color" "$horizontal" "$R"
            ;;
    esac
}

# Fila interior de una tarjeta.
card_row() {
    local color="$1"
    local content="$2"
    local width
    local padding

    width="$(visible_width "$content")"
    padding=$((CARD_INNER - width - 2))

    ((padding < 0)) && padding=0

    printf '%b│%b %b%*s %b│%b' \
        "$color" "$R" \
        "$content" "$padding" "" \
        "$color" "$R"
}

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
    printf '%b  %s%b\n' \
        "$CYAN" \
        "$(repeat_char '─' "$BOX_INNER")" \
        "$R"
}

# ────────────────────────────────────────────────────────────────
# ENCABEZADO
# ────────────────────────────────────────────────────────────────

header() {
    local title subtitle

    clear 2>/dev/null || true

    title="${WHITE}${B}☁ AWS CLOUDFRONT MANAGER${R}"
    subtitle="${GRAY}DASHBOARD DE ADMINISTRACIÓN${R}"

    printf '\n'

    box_top "$CYAN"
    box_row "$CYAN" ""
    box_row "$CYAN" "$(center_text "$title" "$((BOX_INNER - 2))")"
    box_row "$CYAN" "$(center_text "$subtitle" "$((BOX_INNER - 2))")"
    box_row "$CYAN" ""
    box_bottom "$CYAN"

    printf '\n'
}

# ────────────────────────────────────────────────────────────────
# BARRA DE ESTADO
# ────────────────────────────────────────────────────────────────

status_bar() {
    local status

    status="${GREEN}✔ Panel listo${R}                         ${YELLOW}${VERSION}${R}"

    box_top "$GRAY"
    box_row "$GRAY" "$status"
    box_bottom "$GRAY"
}

# ────────────────────────────────────────────────────────────────
# TÍTULOS DE SECCIÓN
# ────────────────────────────────────────────────────────────────

section_title() {
    printf '\n%b\n' "${BLUE}${B}  ◈ $1${R}"
}

# ────────────────────────────────────────────────────────────────
# TARJETAS DEL DASHBOARD
# Dos columnas por dos filas.
# Ancho fijo y relleno calculado automáticamente.
# ────────────────────────────────────────────────────────────────

dashboard_cards() {
    local gap

    gap="$(repeat_char ' ' "$CARD_GAP")"

    # Fila 1: bordes superiores.
    card_border "$BLUE" top
    printf '%s' "$gap"
    card_border "$GREEN" top
    printf '\n'

    # Fila 1: títulos.
    card_row "$BLUE" "☁ ${BLUE}Distribuciones${R}"
    printf '%s' "$gap"
    card_row "$GREEN" "🟢 ${GREEN}Habilitadas${R}"
    printf '\n'

    # Fila 1: valores.
    card_row "$BLUE" "${WHITE}${B}Sin consultar${R}"
    printf '%s' "$gap"
    card_row "$GREEN" "${WHITE}${B}Sin consultar${R}"
    printf '\n'

    # Fila 1: bordes inferiores.
    card_border "$BLUE" bottom
    printf '%s' "$gap"
    card_border "$GREEN" bottom
    printf '\n\n'

    # Fila 2: bordes superiores.
    card_border "$YELLOW" top
    printf '%s' "$gap"
    card_border "$MAGENTA" top
    printf '\n'

    # Fila 2: títulos.
    card_row "$YELLOW" "🟡 ${YELLOW}Deshabilitadas${R}"
    printf '%s' "$gap"
    card_row "$MAGENTA" "🔐 ${MAGENTA}Certificados SSL${R}"
    printf '\n'

    # Fila 2: valores.
    card_row "$YELLOW" "${WHITE}${B}Sin consultar${R}"
    printf '%s' "$gap"
    card_row "$MAGENTA" "${WHITE}${B}Sin consultar${R}"
    printf '\n'

    # Fila 2: bordes inferiores.
    card_border "$YELLOW" bottom
    printf '%s' "$gap"
    card_border "$MAGENTA" bottom
    printf '\n\n'

    printf '%b\n' \
        "${GRAY}  ℹ Las estadísticas requieren una consulta real a AWS.${R}"
}

# ────────────────────────────────────────────────────────────────
# MENÚ PRINCIPAL VISUAL
# ────────────────────────────────────────────────────────────────

dashboard() {
    local menu_width

    header
    status_bar

    section_title "RESUMEN DEL SISTEMA"

    dashboard_cards

    printf '\n'
    line

    section_title "CENTRO DE CONTROL"

    box_top "$CYAN"

    box_row "$CYAN" "${YELLOW}[1]${R}  🚀 Crear distribución"
    box_row "$CYAN" "${YELLOW}[2]${R}  📊 Ver estado de distribuciones"
    box_row "$CYAN" "${YELLOW}[3]${R}  ⚙️ Editar distribución"
    box_row "$CYAN" "${YELLOW}[4]${R}  🔄 Activar / Desactivar distribución"
    box_row "$CYAN" "${YELLOW}[5]${R}  🗑️ Eliminar distribución"

    box_row "$CYAN" ""
    box_separator "$CYAN"
    box_row "$CYAN" ""

    box_row "$CYAN" "${YELLOW}[6]${R}  🔐 Crear certificado SSL"
    box_row "$CYAN" "${YELLOW}[7]${R}  🧹 Remover el panel"
    box_row "$CYAN" "${YELLOW}[8]${R}  🚪 Salir"

    box_bottom "$CYAN"

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
    local confirm

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

                box_top "$CYAN"
                box_row "$CYAN" \
                    "${GREEN}${B}✔ Gracias por utilizar AWS Manager${R}"
                box_row "$CYAN" \
                    "${GRAY}Hasta pronto.${R}"
                box_bottom "$CYAN"

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
