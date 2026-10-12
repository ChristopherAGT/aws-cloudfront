
#!/usr/bin/env bash

set -o pipefail

# ────────────────────────────────────────────────────────────────
# CONFIGURACIÓN
# ────────────────────────────────────────────────────────────────

REPO="https://raw.githubusercontent.com/ChristopherAGT/aws-cloudfront/main"
BIN_DIR="${HOME}/.local/bin"
BIN_PATH="${BIN_DIR}/aws-manager"
VERSION="v1.0"

# Anchos visuales fijos
BOX_INNER=56
CARD_INNER=26

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
    printf '%b\n' "${CYAN}  ──────────────────────────────────────────────────────────${R}"
}

# ────────────────────────────────────────────────────────────────
# CÁLCULO DEL ANCHO VISIBLE
# ────────────────────────────────────────────────────────────────

visible_width() {
    local value="$1"

    # Eliminar secuencias ANSI de color antes de medir.
    value="$(printf '%b' "$value" | sed -E 's/\x1B\[[0-9;]*[[:alpha:]]//g')"

    if command -v python3 >/dev/null 2>&1; then
        printf '%s' "$value" | python3 -c '
import sys
import unicodedata

text = sys.stdin.read()
width = 0
join_next = False

for char in text:
    code = ord(char)

    if unicodedata.combining(char):
        continue

    if char == "\u200d":
        join_next = True
        continue

    if 0xFE00 <= code <= 0xFE0F or 0x1F3FB <= code <= 0x1F3FF:
        continue

    if join_next:
        join_next = False
        continue

    if unicodedata.east_asian_width(char) in ("W", "F"):
        width += 2
    elif 0x1F000 <= code <= 0x1FAFF:
        width += 2
    else:
        width += 1

print(width)
' 2>/dev/null
    else
        # Alternativa para sistemas sin Python 3.
        printf '%s' "$value" | wc -m | tr -d '[:space:]'
    fi
}

# ────────────────────────────────────────────────────────────────
# MARCOS PRINCIPALES DE ANCHO FIJO
# ────────────────────────────────────────────────────────────────

box_top() {
    local color="$1"
    local border

    border="$(printf '%*s' "$BOX_INNER" '' | tr ' ' '─')"

    printf '%b  ╭%s╮%b\n' "$color" "$border" "$R"
}

box_bottom() {
    local color="$1"
    local border

    border="$(printf '%*s' "$BOX_INNER" '' | tr ' ' '─')"

    printf '%b  ╰%s╯%b\n' "$color" "$border" "$R"
}

box_line() {
    local color="$1"
    local content="$2"
    local width padding

    width="$(visible_width "$content")"
    padding=$((BOX_INNER - width - 1))

    if ((padding < 0)); then
        # Evita que una línea demasiado larga rompa el marco.
        content="${content:0:40}"
        width="$(visible_width "$content")"
        padding=$((BOX_INNER - width - 1))
    fi

    ((padding < 0)) && padding=0

    printf '%b  │%b %b%*s%b%b│%b\n' \
        "$color" "$R" \
        "$content" "$padding" "" \
        "$R" "$color" "$R"
}

# ────────────────────────────────────────────────────────────────
# BORDES DE TARJETAS
# ────────────────────────────────────────────────────────────────

card_border() {
    local color="$1"
    local position="$2"
    local border

    border="$(printf '%*s' "$CARD_INNER" '' | tr ' ' '─')"

    case "$position" in
        top)
            printf '%b┌%s┐%b' "$color" "$border" "$R"
            ;;
        bottom)
            printf '%b└%s┘%b' "$color" "$border" "$R"
            ;;
    esac
}

card_line() {
    local color="$1"
    local content="$2"
    local width padding

    width="$(visible_width "$content")"
    padding=$((CARD_INNER - width - 1))

    if ((padding < 0)); then
        content="${content:0:16}"
        width="$(visible_width "$content")"
        padding=$((CARD_INNER - width - 1))
    fi

    ((padding < 0)) && padding=0

    printf '%b│%b %b%*s%b%b│%b' \
        "$color" "$R" \
        "$content" "$padding" "" \
        "$R" "$color" "$R"
}

# ────────────────────────────────────────────────────────────────
# ENCABEZADO
# ────────────────────────────────────────────────────────────────

header() {
    clear 2>/dev/null || true

    printf '\n'
    box_top "$CYAN"

    box_line "$CYAN" ""
    box_line "$CYAN" "${WHITE}${B}☁ AWS CLOUDFRONT MANAGER${R}"
    box_line "$CYAN" "${GRAY}DASHBOARD DE ADMINISTRACIÓN${R}"
    box_line "$CYAN" ""

    box_bottom "$CYAN"
    printf '\n'
}

# ────────────────────────────────────────────────────────────────
# BARRA DE ESTADO
# ────────────────────────────────────────────────────────────────

status_bar() {
    box_top "$GRAY"

    box_line "$GRAY" "${GREEN}✔ Panel listo${R}                         ${YELLOW}${VERSION}${R}"

    box_bottom "$GRAY"
    printf '\n'
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
# ────────────────────────────────────────────────────────────────

dashboard_cards() {
    # Fila superior: bordes superiores.
    card_border "$BLUE" top
    printf '  '
    card_border "$GREEN" top
    printf '\n'

    # Títulos.
    card_line "$BLUE" "☁ ${BLUE}Distribuciones${R}"
    printf '  '
    card_line "$GREEN" "🟢 ${GREEN}Habilitadas${R}"
    printf '\n'

    # Valores.
    card_line "$BLUE" "${WHITE}${B}Sin consultar${R}"
    printf '  '
    card_line "$GREEN" "${WHITE}${B}Sin consultar${R}"
    printf '\n'

    # Bordes inferiores.
    card_border "$BLUE" bottom
    printf '  '
    card_border "$GREEN" bottom
    printf '\n\n'

    # Fila inferior.
    card_border "$YELLOW" top
    printf '  '
    card_border "$MAGENTA" top
    printf '\n'

    card_line "$YELLOW" "🟡 ${YELLOW}Deshabilitadas${R}"
    printf '  '
    card_line "$MAGENTA" "🔐 ${MAGENTA}Certificados SSL${R}"
    printf '\n'

    card_line "$YELLOW" "${WHITE}${B}Sin consultar${R}"
    printf '  '
    card_line "$MAGENTA" "${WHITE}${B}Sin consultar${R}"
    printf '\n'

    card_border "$YELLOW" bottom
    printf '  '
    card_border "$MAGENTA" bottom
    printf '\n\n'

    printf '%b\n' \
        "${GRAY}  ℹ Las estadísticas requieren una consulta real a AWS.${R}"
}

# ────────────────────────────────────────────────────────────────
# DASHBOARD PRINCIPAL
# ────────────────────────────────────────────────────────────────

dashboard() {
    header
    status_bar

    section_title "RESUMEN DEL SISTEMA"
    dashboard_cards

    printf '\n'
    line

    section_title "CENTRO DE CONTROL"

    box_top "$CYAN"

    box_line "$CYAN" "${YELLOW}[1]${R} 🚀 Crear distribución"
    box_line "$CYAN" "${YELLOW}[2]${R} 📊 Ver estado de distribuciones"
    box_line "$CYAN" "${YELLOW}[3]${R} ⚙️ Editar distribución"
    box_line "$CYAN" "${YELLOW}[4]${R} 🔄 Activar / Desactivar distribución"
    box_line "$CYAN" "${YELLOW}[5]${R} 🗑️ Eliminar distribución"

    box_line "$CYAN" ""

    printf '%b\n' "${CYAN}  ├────────────────────────────────────────────────────────┤${R}"

    box_line "$CYAN" ""

    box_line "$CYAN" "${YELLOW}[6]${R} 🔐 Crear certificado SSL"
    box_line "$CYAN" "${YELLOW}[7]${R} 🧹 Remover el panel"
    box_line "$CYAN" "${YELLOW}[8]${R} 🚪 Salir"

    box_bottom "$CYAN"

    printf '\n'
    printf '%b\n' \
        "${GRAY}  AWS CloudFront · Administración · Seguridad SSL${R}"

    printf '\n'
    printf '%b' \
        "${CYAN}${B}  ❯ Selecciona una opción [1-8]: ${R}"
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
                box_top "$CYAN"
                box_line "$CYAN" "${GREEN}${B}✔ Gracias por utilizar AWS Manager${R}"
                box_line "$CYAN" "${GRAY}Hasta pronto.${R}"
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
