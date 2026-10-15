#!/usr/bin/env bash

# ==============================================================
# AWS CLOUDFRONT MANAGER
# Panel administrativo para AWS CloudFront
# Versión: v1.1
# ==============================================================

set -o pipefail

export LC_ALL="${LC_ALL:-C.UTF-8}"
export AWS_PAGER=""

# ────────────────────────────────────────────────────────────────
# CONFIGURACIÓN
# ────────────────────────────────────────────────────────────────

VERSION="v1.2"

REPO="https://raw.githubusercontent.com/ChristopherAGT/aws-cloudfront/main"

BIN_DIR="${HOME}/.local/bin"
BIN_PATH="${BIN_DIR}/aws-manager"

AWS_REGION="us-east-1"
AWS_ACM_REGION="${AWS_ACM_REGION:-us-east-1}"

# Dimensiones fijas del panel principal.
#
# Ancho total:
#   2 espacios de margen + 46 columnas = 48 columnas.
#
# Interior:
#   1 borde + 1 espacio + 42 columnas + 1 espacio + 1 borde.
#
BOX_INNER=44
BOX_CONTENT=42
LINE_WIDTH=46

# Dimensiones de las tarjetas.
#
# Cada tarjeta:
#   1 borde + 1 espacio + 18 columnas + 1 espacio + 1 borde.
#
# Dos tarjetas:
#   22 + 2 de separación + 22 = 46 columnas.
#
CARD_INNER=20
CARD_CONTENT=18
CARD_GAP=2

# Estadísticas de AWS.

AWS_ACCOUNT="Sin consultar"
AWS_STATUS="Sin consultar"

TOTAL_DISTRIBUTIONS="--"
ACTIVE_DISTRIBUTIONS="--"
DISABLED_DISTRIBUTIONS="--"
PENDING_DISTRIBUTIONS="--"
TOTAL_CERTIFICATES="--"

AWS_CONNECTED=false
AWS_STATS_LOADED=false

# ────────────────────────────────────────────────────────────────
# COLORES
# ────────────────────────────────────────────────────────────────

if [[ -t 1 ]]; then
    R='\033[0m'
    B='\033[1m'
    D='\033[2m'

    RED='\033[31m'
    GREEN='\033[32m'
    YELLOW='\033[33m'
    BLUE='\033[34m'
    MAGENTA='\033[35m'
    CYAN='\033[36m'
    WHITE='\033[97m'

    BG_BLUE='\033[44m'
    BG_CYAN='\033[46m'
else
    R=''
    B=''
    D=''

    RED=''
    GREEN=''
    YELLOW=''
    BLUE=''
    MAGENTA=''
    CYAN=''
    WHITE=''

    BG_BLUE=''
    BG_CYAN=''
fi

# ────────────────────────────────────────────────────────────────
# UTILIDADES DE DIMENSIONES
# ────────────────────────────────────────────────────────────────

strip_ansi() {
    local text="${1-}"

    printf '%s' "$text" |
        sed -E 's/\x1B\[[0-9;?]*[[:alpha:]]//g'
}

# Calcula el ancho visible del texto sin contar códigos ANSI.
#
# Considera:
#   - Caracteres combinados.
#   - Caracteres de ancho completo.
#   - Variantes emoji.
#   - Secuencias emoji unidas mediante ZWJ.
#   - Banderas formadas por indicadores regionales.
#
# La medición se realiza sobre el texto sin códigos ANSI.

visible_width() {
    local text="${1-}"

    python3 -c '
import sys
import unicodedata
import re

text = sys.stdin.read()

# Eliminar secuencias ANSI.
text = re.sub(r"\x1b\[[0-?]*[ -/]*[@-~]", "", text)

width = 0
i = 0
n = len(text)

def is_regional(c):
    return 0x1F1E6 <= ord(c) <= 0x1F1FF

def is_emoji_modifier(c):
    return 0x1F3FB <= ord(c) <= 0x1F3FF

def char_width(c):
    cp = ord(c)

    if unicodedata.combining(c):
        return 0

    if cp in (0xFE0E, 0xFE0F, 0x200D):
        return 0

    if 0xE0100 <= cp <= 0xE01EF:
        return 0

    if 0xFE00 <= cp <= 0xFE0F:
        return 0

    if unicodedata.category(c) in ("Mn", "Me", "Cf"):
        return 0

    if unicodedata.east_asian_width(c) in ("W", "F"):
        return 2

    return 1

while i < n:
    c = text[i]

    if c == "\n" or c == "\r":
        i += 1
        continue

    # Las banderas suelen representarse con dos indicadores.
    if is_regional(c):
        width += 2
        i += 1

        if i < n and is_regional(text[i]):
            i += 1

        continue

    # Agrupar secuencias emoji unidas por ZWJ.
    if char_width(c) == 2:
        width += 2
        i += 1

        while i < n:
            cp = ord(text[i])

            # Selectores de variación y modificadores.
            if (
                cp in (0xFE0E, 0xFE0F)
                or 0x1F3FB <= cp <= 0x1F3FF
                or 0xE0100 <= cp <= 0xE01EF
            ):
                i += 1
                continue

            # Caracteres combinados.
            if unicodedata.combining(text[i]):
                i += 1
                continue

            # Unir el siguiente emoji a la secuencia actual.
            if cp == 0x200D and i + 1 < n:
                i += 2

                while i < n:
                    next_cp = ord(text[i])

                    if (
                        next_cp in (0xFE0E, 0xFE0F)
                        or 0x1F3FB <= next_cp <= 0x1F3FF
                        or 0xE0100 <= next_cp <= 0xE01EF
                    ):
                        i += 1
                        continue

                    if unicodedata.combining(text[i]):
                        i += 1
                        continue

                    break

                continue

            break

        continue

    width += char_width(c)
    i += 1

print(width)
' <<< "$text"
}

repeat_char() {
    local char="${1-─}"
    local count="${2:-0}"

    (( count > 0 )) || return 0

    printf '%*s' "$count" '' |
        tr ' ' "$char"
}

# Ajusta un texto al ancho visible especificado.
#
# El relleno se calcula después de medir el texto sin ANSI.
# El texto no se trunca mediante eliminación de caracteres Bash,
# evitando cortar accidentalmente una secuencia de color.

fit_text() {
    local text="${1-}"
    local target="${2:-0}"
    local plain
    local width
    local remaining

    plain="$(strip_ansi "$text")"
    width="$(visible_width "$plain")"

    if (( width > target )); then
        plain="$(
            python3 -c '
import sys
import unicodedata

text = sys.stdin.read()
target = int(sys.argv[1])

out = []
width = 0

for c in text:
    cp = ord(c)

    if c in ("\n", "\r"):
        continue

    if unicodedata.combining(c):
        out.append(c)
        continue

    if cp in (0xFE0E, 0xFE0F, 0x200D):
        out.append(c)
        continue

    if unicodedata.category(c) == "Cf":
        out.append(c)
        continue

    char_width = (
        2
        if unicodedata.east_asian_width(c) in ("W", "F")
        else 1
    )

    if width + char_width > target:
        break

    out.append(c)
    width += char_width

print("".join(out), end="")
' "$target" <<< "$plain"
        )"

        text="$plain"
        width="$(visible_width "$plain")"
    fi

    remaining=$(( target - width ))

    (( remaining < 0 )) && remaining=0

    printf '%s%*s' "$text" "$remaining" ''
}

center_text() {
    local text="${1-}"
    local target="${2:-0}"
    local plain
    local width
    local left
    local right

    plain="$(strip_ansi "$text")"
    width="$(visible_width "$plain")"

    if (( width > target )); then
        text="$(fit_text "$plain" "$target")"
        width="$(visible_width "$text")"
    fi

    left=$(( (target - width) / 2 ))
    right=$(( target - width - left ))

    printf '%*s%s%*s' "$left" '' "$text" "$right" ''
}

# ────────────────────────────────────────────────────────────────
# BORDES Y FILAS DEL PANEL
# ────────────────────────────────────────────────────────────────

box_top() {
    printf '  ┌%s┐\n' "$(repeat_char '─' "$BOX_INNER")"
}

box_bottom() {
    printf '  └%s┘\n' "$(repeat_char '─' "$BOX_INNER")"
}

box_separator() {
    printf '  ├%s┤\n' "$(repeat_char '─' "$BOX_INNER")"
}

box_row() {
    local text="${1-}"
    local content

    content="$(fit_text "$text" "$BOX_CONTENT")"

    printf '  │ %s │\n' "$content"
}

box_center() {
    local text="${1-}"
    local centered

    centered="$(center_text "$text" "$BOX_CONTENT")"

    box_row "$centered"
}

line() {
    printf '  %s\n' "$(repeat_char '─' "$LINE_WIDTH")"
}

# ────────────────────────────────────────────────────────────────
# TARJETAS DEL DASHBOARD
# ────────────────────────────────────────────────────────────────

card_top() {
    local color="${1-}"
    local border

    border="$(repeat_char '─' "$CARD_INNER")"

    printf '%b┌%s┐%b' "$color" "$border" "$R"
}

card_bottom() {
    local color="${1-}"
    local border

    border="$(repeat_char '─' "$CARD_INNER")"

    printf '%b└%s┘%b' "$color" "$border" "$R"
}

card_separator() {
    local color="${1-}"
    local border

    border="$(repeat_char '─' "$CARD_INNER")"

    printf '%b├%s┤%b' "$color" "$border" "$R"
}

card_row() {
    local text="${1-}"
    local color="${2-}"
    local content

    content="$(fit_text "$text" "$CARD_CONTENT")"

    printf '%b│%b %s %b│%b' \
        "$color" "$R" "$content" "$color" "$R"
}

card_pair_row() {
    local left="${1-}"
    local right="${2-}"
    local left_color="${3-${CYAN}}"
    local right_color="${4-${BLUE}}"

    printf '  '
    card_row "$left" "$left_color"
    printf '%*s' "$CARD_GAP" ''
    card_row "$right" "$right_color"
    printf '\n'
}

card_pair_top() {
    local left_color="${1-${CYAN}}"
    local right_color="${2-${BLUE}}"

    printf '  '
    card_top "$left_color"
    printf '%*s' "$CARD_GAP" ''
    card_top "$right_color"
    printf '\n'
}

card_pair_separator() {
    local left_color="${1-${CYAN}}"
    local right_color="${2-${BLUE}}"

    printf '  '
    card_separator "$left_color"
    printf '%*s' "$CARD_GAP" ''
    card_separator "$right_color"
    printf '\n'
}

card_pair_bottom() {
    local left_color="${1-${CYAN}}"
    local right_color="${2-${BLUE}}"

    printf '  '
    card_bottom "$left_color"
    printf '%*s' "$CARD_GAP" ''
    card_bottom "$right_color"
    printf '\n'
}

# ────────────────────────────────────────────────────────────────
# INSTALACIÓN DEL COMANDO
# ────────────────────────────────────────────────────────────────

install_manager() {
    local source_path
    local source_real
    local target_real

    source_path="$0"

    mkdir -p "$BIN_DIR" || {
        printf '%b❌ No se pudo crear el directorio de instalación.%b\n' \
            "$RED" "$R"
        return 1
    }

    source_real="$(
        readlink -f "$source_path" 2>/dev/null ||
        printf '%s' "$source_path"
    )"

    target_real="$(
        readlink -f "$BIN_PATH" 2>/dev/null ||
        printf '%s' "$BIN_PATH"
    )"

    if [[ "$source_real" != "$target_real" ]]; then
        if ! cp "$source_path" "$BIN_PATH"; then
            printf '%b❌ No se pudo instalar el comando.%b\n' \
                "$RED" "$R"
            return 1
        fi
    fi

    chmod +x "$BIN_PATH" || {
        printf '%b❌ No se pudieron establecer los permisos.%b\n' \
            "$RED" "$R"
        return 1
    }

    if [[ "$source_real" != "$target_real" ]]; then
        exec "$BIN_PATH" "$@"
    fi
}

# ────────────────────────────────────────────────────────────────
# DEPENDENCIAS
# ────────────────────────────────────────────────────────────────

check_dependencies() {
    local dependencies=(
        curl
        bash
        awk
        jq
        aws
        mktemp
        python3
        readlink
        sed
    )

    local dependency
    local missing=()

    for dependency in "${dependencies[@]}"; do
        if ! command -v "$dependency" >/dev/null 2>&1; then
            missing+=("$dependency")
        fi
    done

    if (( ${#missing[@]} > 0 )); then
        printf '\n%b❌ Faltan las siguientes dependencias:%b\n' \
            "$RED" "$R"

        for dependency in "${missing[@]}"; do
            printf '  %b•%b %s\n' "$YELLOW" "$R" "$dependency"
        done

        printf '\n%bInstala las dependencias necesarias y vuelve a ejecutar el panel.%b\n' \
            "$YELLOW" "$R"

        return 1
    fi

    return 0
}

# ────────────────────────────────────────────────────────────────
# ESTADÍSTICAS DE AWS
# ────────────────────────────────────────────────────────────────

load_aws_statistics() {
    local identity
    local distributions
    local certificates

    AWS_STATS_LOADED=true

    AWS_ACCOUNT="Sin consultar"
    AWS_STATUS="Sin consultar"

    TOTAL_DISTRIBUTIONS="--"
    ACTIVE_DISTRIBUTIONS="--"
    DISABLED_DISTRIBUTIONS="--"
    PENDING_DISTRIBUTIONS="--"
    TOTAL_CERTIFICATES="--"

    AWS_CONNECTED=false

    printf '\n%b⏳ Consultando estadísticas de AWS...%b\n' \
        "$CYAN" "$R"

    if ! identity="$(
        aws sts get-caller-identity \
            --region "$AWS_REGION" \
            --output json 2>/dev/null
    )"; then
        AWS_STATUS="Sin conexión"
        AWS_ACCOUNT="No disponible"

        printf '%b⚠ No se pudo consultar la identidad de AWS.%b\n' \
            "$YELLOW" "$R"

        return 1
    fi

    AWS_ACCOUNT="$(
        jq -r '.Account // "No disponible"' <<< "$identity"
    )"

    AWS_STATUS="Conectado"
    AWS_CONNECTED=true

    if distributions="$(
        aws cloudfront list-distributions \
            --output json 2>/dev/null
    )"; then

        TOTAL_DISTRIBUTIONS="$(
            jq -r '
                (.DistributionList.Items // []) | length
            ' <<< "$distributions"
        )"

        ACTIVE_DISTRIBUTIONS="$(
            jq -r '
                [
                    (.DistributionList.Items // [])[]
                    | select(
                        .Enabled == true
                        and .Status == "Deployed"
                    )
                ] | length
            ' <<< "$distributions"
        )"

        DISABLED_DISTRIBUTIONS="$(
            jq -r '
                [
                    (.DistributionList.Items // [])[]
                    | select(.Enabled == false)
                ] | length
            ' <<< "$distributions"
        )"

        PENDING_DISTRIBUTIONS="$(
            jq -r '
                [
                    (.DistributionList.Items // [])[]
                    | select(.Status != "Deployed")
                ] | length
            ' <<< "$distributions"
        )"
    else
        TOTAL_DISTRIBUTIONS="Error"
        ACTIVE_DISTRIBUTIONS="Error"
        DISABLED_DISTRIBUTIONS="Error"
        PENDING_DISTRIBUTIONS="Error"
    fi

    if certificates="$(
        aws acm list-certificates \
            --region "$AWS_ACM_REGION" \
            --certificate-statuses ISSUED \
            --output json 2>/dev/null
    )"; then

        TOTAL_CERTIFICATES="$(
            jq -r '
                (.CertificateSummaryList // []) | length
            ' <<< "$certificates"
        )"
    else
        TOTAL_CERTIFICATES="Error"
    fi

    printf '%b✓ Consulta de AWS finalizada.%b\n' \
        "$GREEN" "$R"

    return 0
}

# ────────────────────────────────────────────────────────────────
# INTERFAZ
# ────────────────────────────────────────────────────────────────

pause() {
    printf '\n%bPresiona ENTER para continuar...%b' "$YELLOW" "$R"
    read -r _
}

header() {
    local title
    local subtitle
    local version

    clear 2>/dev/null || true

    title="☁ AWS CLOUDFRONT MANAGER"
    subtitle="Panel de administración de Amazon CloudFront"
    version="Versión ${VERSION}"

    box_top

    box_center "${CYAN}${B}${title}${R}"

    box_separator

    box_center "${WHITE}${subtitle}${R}"
    box_center "${D}${version}${R}"

    box_bottom

    printf '\n'
}

status_bar() {
    local label
    local value
    local color

    label="${1-Estado}"
    value="${2-Sin consultar}"
    color="${3-${YELLOW}}"

    printf '  %b●%b %s: %b%s%b\n' \
        "$color" "$R" "$label" "$color" "$value" "$R"
}

section_title() {
    local title="${1-}"

    printf '\n'
    printf '  %b%s%b\n' "$B$CYAN" "$title" "$R"
    printf '  %b%s%b\n' "$CYAN" \
        "$(repeat_char '─' "$LINE_WIDTH")" "$R"
}

# ────────────────────────────────────────────────────────────────
# DASHBOARD: CUATRO TARJETAS
# ────────────────────────────────────────────────────────────────

dashboard_cards() {
    # Fila superior: distribuciones y estado del servicio.

    card_pair_top "$CYAN" "$BLUE"

    card_pair_row \
        "☁ DISTRIBUCIONES" \
        "⚙ ESTADO AWS" \
        "$CYAN" "$BLUE"

    card_pair_separator "$CYAN" "$BLUE"

    card_pair_row \
        "Total: ${TOTAL_DISTRIBUTIONS}" \
        "Estado: ${AWS_STATUS}" \
        "$CYAN" "$BLUE"

    card_pair_row \
        "Activas: ${ACTIVE_DISTRIBUTIONS}" \
        "Cuenta AWS:" \
        "$CYAN" "$BLUE"

    card_pair_row \
        "Deshabil.: ${DISABLED_DISTRIBUTIONS}" \
        "${AWS_ACCOUNT}" \
        "$CYAN" "$BLUE"

    card_pair_row \
        "Pendientes: ${PENDING_DISTRIBUTIONS}" \
        "Región: ${AWS_REGION}" \
        "$CYAN" "$BLUE"

    card_pair_bottom "$CYAN" "$BLUE"

    printf '\n'

    # Fila inferior: certificados y consulta.

    card_pair_top "$MAGENTA" "$GREEN"

    card_pair_row \
        "🔐 CERTIFICADOS SSL" \
        "📊 CONSULTA AWS" \
        "$MAGENTA" "$GREEN"

    card_pair_separator "$MAGENTA" "$GREEN"

    card_pair_row \
        "Emitidos: ${TOTAL_CERTIFICATES}" \
        "CloudFront: ${TOTAL_DISTRIBUTIONS}" \
        "$MAGENTA" "$GREEN"

    card_pair_row \
        "Región ACM:" \
        "Operativas: ${ACTIVE_DISTRIBUTIONS}" \
        "$MAGENTA" "$GREEN"

    card_pair_row \
        "${AWS_ACM_REGION}" \
        "Deshabil.: ${DISABLED_DISTRIBUTIONS}" \
        "$MAGENTA" "$GREEN"

    card_pair_row \
        "Estado: $([[ "$AWS_CONNECTED" == true ]] && printf 'OK' || printf 'N/D')" \
        "Pendientes: ${PENDING_DISTRIBUTIONS}" \
        "$MAGENTA" "$GREEN"

    card_pair_bottom "$MAGENTA" "$GREEN"
}

dashboard() {
    printf '\n'

    section_title "DASHBOARD GENERAL"

    dashboard_cards

    printf '\n'

    status_bar \
        "Conexión AWS" \
        "$AWS_STATUS" \
        "$([[ "$AWS_CONNECTED" == true ]] && printf '%s' "$GREEN" || printf '%s' "$YELLOW")"

    printf '\n'
}

# ────────────────────────────────────────────────────────────────
# EJECUCIÓN DE MÓDULOS
# ────────────────────────────────────────────────────────────────

run_module() {
    local module="${1-}"
    local url="${REPO}/${module}"
    local temporary_file

    temporary_file="$(mktemp 2>/dev/null)" || {
        printf '%b❌ No se pudo crear un archivo temporal.%b\n' \
            "$RED" "$R"
        pause
        return 1
    }

    printf '\n%b⏳ Descargando módulo: %s%b\n' \
        "$CYAN" "$module" "$R"

    if ! curl -fsSL "$url" -o "$temporary_file"; then
        printf '%b❌ No se pudo descargar el módulo.%b\n' \
            "$RED" "$R"

        rm -f "$temporary_file"
        pause
        return 1
    fi

    if [[ ! -s "$temporary_file" ]]; then
        printf '%b❌ El módulo descargado está vacío.%b\n' \
            "$RED" "$R"

        rm -f "$temporary_file"
        pause
        return 1
    fi

    if ! bash -n "$temporary_file"; then
        printf '%b❌ El módulo contiene errores de sintaxis.%b\n' \
            "$RED" "$R"

        rm -f "$temporary_file"
        pause
        return 1
    fi

    chmod +x "$temporary_file"

    bash "$temporary_file"
    local result=$?

    rm -f "$temporary_file"

    if (( result != 0 )); then
        printf '\n%b⚠ El módulo finalizó con código %s.%b\n' \
            "$YELLOW" "$result" "$R"
    fi

    pause

    return "$result"
}

# ────────────────────────────────────────────────────────────────
# DESINSTALACIÓN DEL PANEL
# ────────────────────────────────────────────────────────────────

uninstall_manager() {
    local confirmation

    printf '\n'

    box_top
    box_center "${RED}${B}DESINSTALACIÓN DEL PANEL${R}"
    box_separator
    box_center "Se eliminará el comando local:"
    box_center "${YELLOW}${BIN_PATH}${R}"
    box_bottom

    printf '\n'
    printf '%b¿Deseas continuar? [s/N]: %b' "$YELLOW" "$R"

    read -r confirmation

    case "$confirmation" in
        s|S|si|SI|Si|sí|Sí|SÍ)
            if [[ -f "$BIN_PATH" ]]; then
                if rm -f "$BIN_PATH"; then
                    printf '\n%b✓ Panel desinstalado correctamente.%b\n' \
                        "$GREEN" "$R"
                else
                    printf '\n%b❌ No se pudo eliminar el comando.%b\n' \
                        "$RED" "$R"
                fi
            else
                printf '\n%b⚠ El comando no existe en la ruta indicada.%b\n' \
                    "$YELLOW" "$R"
            fi
            ;;
        *)
            printf '\n%bOperación cancelada.%b\n' "$YELLOW" "$R"
            ;;
    esac

    pause
}

# ────────────────────────────────────────────────────────────────
# MENÚ PRINCIPAL
# ────────────────────────────────────────────────────────────────

main() {
    local option

    install_manager "$@" || return 1

    if ! check_dependencies; then
        pause
        return 1
    fi

    while true; do
        header
        dashboard

        section_title "ADMINISTRACIÓN CLOUDFRONT"

        box_top
        box_row "${GREEN}[1]${R} Crear distribución CloudFront"
        box_row "${CYAN}[2]${R} Consultar distribuciones"
        box_row "${YELLOW}[3]${R} Editar distribución"
        box_row "${MAGENTA}[4]${R} Controlar estado de distribución"
        box_row "${RED}[5]${R} Eliminar distribución"
        box_row "${BLUE}[6]${R} Crear certificado SSL/TLS"
        box_separator
        box_row "${CYAN}[7]${R} Actualizar estadísticas AWS"
        box_row "${RED}[8]${R} Desinstalar panel"
        box_separator
        box_row "${YELLOW}[0]${R} Salir"
        box_bottom

        printf '\n'
        printf '  %bSelecciona una opción:%b ' "$B$CYAN" "$R"

        read -r option

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
                run_module "delete-distribution.sh"
                ;;
            6)
                run_module "create-certificate.sh"
                ;;
            7)
                load_aws_statistics
                pause
                ;;
            8)
                uninstall_manager
                ;;
            0)
                clear 2>/dev/null || true

                printf '\n'
                box_top
                box_center "${GREEN}${B}¡GRACIAS POR UTILIZAR AWS CLOUDFRONT MANAGER!${R}"
                box_center "Saliendo del panel..."
                box_bottom
                printf '\n'

                exit 0
                ;;
            *)
                printf '\n%b❌ Opción no válida.%b\n' "$RED" "$R"
                pause
                ;;
        esac
    done
}

main "$@"
