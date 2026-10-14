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

REPO="https://raw.githubusercontent.com/ChristopherAGT/aws-cloudfront/main"
BIN_DIR="${HOME}/.local/bin"
BIN_PATH="${BIN_DIR}/aws-manager"
VERSION="v1.3"

AWS_REGION="us-east-1"
AWS_ACM_REGION="${AWS_ACM_REGION:-us-east-1}"

TOTAL_DISTRIBUTIONS="N/D"
ENABLED_DISTRIBUTIONS="N/D"
DISABLED_DISTRIBUTIONS="N/D"
SSL_CERTIFICATES="N/D"
ENABLED_PENDING_DISTRIBUTIONS="N/D"

AWS_CONNECTION_STATUS="Sin verificar"
CF_STATS_OK=0
ACM_STATS_OK=0

# ────────────────────────────────────────────────────────────────
# DIMENSIONES FIJAS
# ────────────────────────────────────────────────────────────────

# Panel: 1 + 44 + 1 = 46 columnas.
# Contenido: 1 + 1 + 42 + 1 + 1 = 46 columnas.
# Tarjeta: 1 + 20 + 1 = 22 columnas.
# Dos tarjetas: 22 + 2 + 22 = 46 columnas.

BOX_INNER=44
BOX_CONTENT=42
LINE_WIDTH=46

CARD_INNER=20
CARD_CONTENT=18
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
    R='' B='' D=''
    RED='' GREEN='' YELLOW=''
    BLUE='' MAGENTA='' CYAN=''
    WHITE='' GRAY=''
fi

# ────────────────────────────────────────────────────────────────
# UTILIDADES DE TEXTO Y ALINEACIÓN
# ────────────────────────────────────────────────────────────────

# Elimina secuencias ANSI.
strip_ansi() {
    printf '%s' "$1" |
        python3 -c '
import re
import sys

text = sys.stdin.read()
text = re.sub(
    r"\x1b(?:[@-Z\\-_]|\[[0-?]*[ -/]*[@-~])",
    "",
    text
)
sys.stdout.write(text)
'
}

# Calcula el ancho visual del texto Unicode.
visible_width() {
    printf '%s' "$1" |
        python3 -c '
import re
import sys
import unicodedata

text = sys.stdin.read()

text = re.sub(
    r"\x1b(?:[@-Z\\-_]|\[[0-?]*[ -/]*[@-~])",
    "",
    text
)

width = 0
i = 0

while i < len(text):
    char = text[i]
    code = ord(char)

    # Caracteres de unión y selectores de presentación.
    if code in (0x200D, 0xFE0E, 0xFE0F):
        i += 1
        continue

    # Marcas combinantes y selectores suplementarios.
    if unicodedata.combining(char) or 0xE0100 <= code <= 0xE01EF:
        i += 1
        continue

    # Banderas.
    if 0x1F1E6 <= code <= 0x1F1FF:
        width += 2

        if i + 1 < len(text):
            next_code = ord(text[i + 1])
            if 0x1F1E6 <= next_code <= 0x1F1FF:
                i += 1

        i += 1
        continue

    # Símbolos con selector de presentación emoji.
    if i + 1 < len(text) and ord(text[i + 1]) == 0xFE0F:
        width += 2
        i += 2
        continue

    # Caracteres de ancho doble.
    if (
        unicodedata.east_asian_width(char) in ("W", "F")
        or 0x1F000 <= code <= 0x1FAFF
        or 0x2600 <= code <= 0x27BF
    ):
        width += 2
    else:
        width += 1

    i += 1

print(width)
'
}

# Genera caracteres repetidos.
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

# Ajusta el texto a un ancho exacto.
# El contenido de los marcos utiliza caracteres de ancho predecible.
fit_text() {
    local content="$1"
    local target_width="$2"
    local plain
    local width
    local padding

    plain="$(strip_ansi "$content")"
    width="$(visible_width "$plain")"

    if ((width > target_width)); then
        content="$plain"

        while ((width > target_width)) && [[ -n "$content" ]]; do
            content="${content%?}"
            width="$(visible_width "$content")"
        done
    fi

    padding=$((target_width - width))
    ((padding < 0)) && padding=0

    printf '%b' "$content"
    printf '%*s' "$padding" ''
}

# Centra el texto según su ancho visual.
center_text() {
    local content="$1"
    local total="$2"
    local plain
    local width
    local left
    local right

    plain="$(strip_ansi "$content")"
    width="$(visible_width "$plain")"

    if ((width >= total)); then
        fit_text "$content" "$total"
        return
    fi

    left=$(((total - width) / 2))
    right=$((total - width - left))

    printf '%*s%b%*s' "$left" "" "$content" "$right" ""
}

# ────────────────────────────────────────────────────────────────
# MARCOS DEL PANEL GENERAL
# ────────────────────────────────────────────────────────────────

box_top() {
    local color="$1"
    local horizontal

    horizontal="$(repeat_char '─' "$BOX_INNER")"

    printf '  %b╭%s╮%b\n' "$color" "$horizontal" "$R"
}

box_bottom() {
    local color="$1"
    local horizontal

    horizontal="$(repeat_char '─' "$BOX_INNER")"

    printf '  %b╰%s╯%b\n' "$color" "$horizontal" "$R"
}

box_separator() {
    local color="$1"
    local horizontal

    horizontal="$(repeat_char '─' "$BOX_INNER")"

    printf '  %b├%s┤%b\n' "$color" "$horizontal" "$R"
}

# Cada fila conserva exactamente 46 columnas visuales.
box_row() {
    local color="$1"
    local content="$2"
    local fitted

    fitted="$(fit_text "$content" "$BOX_CONTENT")"

    printf '  %b│%b %b %b│%b\n' \
        "$color" \
        "$R" \
        "$fitted" \
        "$color" \
        "$R"
}

# Línea divisoria.
line() {
    printf '  %b%s%b\n' \
        "$CYAN" \
        "$(repeat_char '─' "$LINE_WIDTH")" \
        "$R"
}

# ────────────────────────────────────────────────────────────────
# TARJETAS DEL DASHBOARD
# ────────────────────────────────────────────────────────────────

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

# Cada fila de tarjeta conserva 22 columnas.
card_row() {
    local color="$1"
    local content="$2"
    local fitted

    fitted="$(fit_text "$content" "$CARD_CONTENT")"

    printf '%b│%b %b %b│%b' \
        "$color" \
        "$R" \
        "$fitted" \
        "$color" \
        "$R"
}

# ────────────────────────────────────────────────────────────────
# INSTALACIÓN COMO COMANDO GLOBAL
# ────────────────────────────────────────────────────────────────

install_manager() {
    local source_path
    local resolved_bin
    local resolved_source
    local temp_install

    source_path="$0"

    resolved_source="$(readlink -f -- "$source_path" 2>/dev/null || true)"
    resolved_bin="$(readlink -f -- "$BIN_PATH" 2>/dev/null || true)"

    # Si ya se ejecuta el archivo instalado, no volver a copiarlo.
    if [[ -n "$resolved_source" &&
          -n "$resolved_bin" &&
          "$resolved_source" == "$resolved_bin" ]]; then
        return 0
    fi

    if [[ ! -f "$source_path" ]]; then
        printf '%b\n' "${RED}✖ No se encuentra el archivo del panel.${R}"
        exit 1
    fi

    if ! mkdir -p -- "$BIN_DIR"; then
        printf '%b\n' "${RED}✖ No se pudo crear ${BIN_DIR}.${R}"
        exit 1
    fi

    temp_install="$(mktemp "${BIN_DIR}/.aws-manager.XXXXXX" 2>/dev/null)" || {
        printf '%b\n' "${RED}✖ No se pudo crear el archivo temporal.${R}"
        exit 1
    }

    if ! cp -- "$source_path" "$temp_install"; then
        rm -f -- "$temp_install"
        printf '%b\n' "${RED}✖ No se pudo preparar la nueva versión.${R}"
        exit 1
    fi

    if ! chmod 700 "$temp_install"; then
        rm -f -- "$temp_install"
        printf '%b\n' "${RED}✖ No se pudieron establecer los permisos.${R}"
        exit 1
    fi

    if ! mv -f -- "$temp_install" "$BIN_PATH"; then
        rm -f -- "$temp_install"
        printf '%b\n' "${RED}✖ No se pudo instalar aws-manager.${R}"
        exit 1
    fi

    printf '\n%b\n' "${GREEN}✔ AWS Manager actualizado correctamente.${R}"
    printf '%b\n\n' "${GRAY}Comando: ${BIN_PATH}${R}"

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
    command -v awk >/dev/null 2>&1 || missing+=("awk")
    command -v jq >/dev/null 2>&1 || missing+=("jq")
    command -v aws >/dev/null 2>&1 || missing+=("aws-cli")
    command -v mktemp >/dev/null 2>&1 || missing+=("mktemp")
    command -v python3 >/dev/null 2>&1 || missing+=("python3")
    command -v readlink >/dev/null 2>&1 || missing+=("readlink")

    if ((${#missing[@]} > 0)); then
        printf '\n%b\n' \
            "${RED}✖ Faltan dependencias: ${missing[*]}${R}"

        printf '%b\n' \
            "${YELLOW}Instala las herramientas faltantes y vuelve a ejecutar el panel.${R}"

        exit 1
    fi
}

# ────────────────────────────────────────────────────────────────
# CONSULTA REAL A AWS
# ────────────────────────────────────────────────────────────────

load_aws_statistics() {
    local distributions_json
    local certificates_json
    local total
    local enabled
    local disabled
    local enabled_pending
    local certificates

    TOTAL_DISTRIBUTIONS="N/D"
    ENABLED_DISTRIBUTIONS="N/D"
    DISABLED_DISTRIBUTIONS="N/D"
    SSL_CERTIFICATES="N/D"
    ENABLED_PENDING_DISTRIBUTIONS="N/D"

    AWS_CONNECTION_STATUS="Error de conexión"
    CF_STATS_OK=0
    ACM_STATS_OK=0

    # Verificar credenciales.
    if ! aws sts get-caller-identity \
        --output json >/dev/null 2>&1; then

        AWS_CONNECTION_STATUS="Error de autenticación"
        return 1
    fi

    # Consultar distribuciones de CloudFront.
    if distributions_json="$(
        aws cloudfront list-distributions \
            --output json 2>/dev/null
    )"; then

        if printf '%s' "$distributions_json" |
            jq -e '
                (.DistributionList.Items // [])
                | type == "array"
            ' >/dev/null 2>&1; then

            total="$(
                printf '%s' "$distributions_json" |
                    jq -r '
                        (.DistributionList.Items // [])
                        | length
                    '
            )"

            enabled="$(
                printf '%s' "$distributions_json" |
                    jq -r '
                        [
                            (.DistributionList.Items // [])[]
                            | select(
                                .Enabled == true
                                and .Status == "Deployed"
                            )
                        ]
                        | length
                    '
            )"

            disabled="$(
                printf '%s' "$distributions_json" |
                    jq -r '
                        [
                            (.DistributionList.Items // [])[]
                            | select(.Enabled == false)
                        ]
                        | length
                    '
            )"

            enabled_pending="$(
                printf '%s' "$distributions_json" |
                    jq -r '
                        [
                            (.DistributionList.Items // [])[]
                            | select(
                                .Enabled == true
                                and .Status != "Deployed"
                            )
                        ]
                        | length
                    '
            )"

            if [[ "$total" =~ ^[0-9]+$ &&
                  "$enabled" =~ ^[0-9]+$ &&
                  "$disabled" =~ ^[0-9]+$ &&
                  "$enabled_pending" =~ ^[0-9]+$ ]]; then

                TOTAL_DISTRIBUTIONS="$total"
                ENABLED_DISTRIBUTIONS="$enabled"
                DISABLED_DISTRIBUTIONS="$disabled"
                ENABLED_PENDING_DISTRIBUTIONS="$enabled_pending"

                CF_STATS_OK=1
            fi
        fi
    fi

    # Consultar certificados emitidos en ACM.
    if certificates_json="$(
        aws acm list-certificates \
            --region "$AWS_ACM_REGION" \
            --certificate-statuses ISSUED \
            --output json 2>/dev/null
    )"; then

        if printf '%s' "$certificates_json" |
            jq -e '
                (.CertificateSummaryList // [])
                | type == "array"
            ' >/dev/null 2>&1; then

            certificates="$(
                printf '%s' "$certificates_json" |
                    jq -r '
                        (.CertificateSummaryList // [])
                        | length
                    '
            )"

            if [[ "$certificates" =~ ^[0-9]+$ ]]; then
                SSL_CERTIFICATES="$certificates"
                ACM_STATS_OK=1
            fi
        fi
    fi

    # Determinar el estado de las consultas.
    if ((CF_STATS_OK == 1 && ACM_STATS_OK == 1)); then
        AWS_CONNECTION_STATUS="Conectado a AWS"
    elif ((CF_STATS_OK == 1 && ACM_STATS_OK == 0)); then
        AWS_CONNECTION_STATUS="CloudFront OK; error en ACM"
    elif ((CF_STATS_OK == 0 && ACM_STATS_OK == 1)); then
        AWS_CONNECTION_STATUS="ACM OK; error en CloudFront"
    else
        AWS_CONNECTION_STATUS="Error consultando AWS"
    fi

    ((CF_STATS_OK == 1 && ACM_STATS_OK == 1))
}

# ────────────────────────────────────────────────────────────────
# PAUSA
# ────────────────────────────────────────────────────────────────

pause() {
    printf '\n'

    read -r -p \
        "$(printf '%b' "${GRAY}Presiona ENTER para continuar...${R}")" _
}

# ────────────────────────────────────────────────────────────────
# ENCABEZADO
# ────────────────────────────────────────────────────────────────

header() {
    local title
    local subtitle

    clear 2>/dev/null || true

    # Sin emoji en el marco para evitar diferencias de ancho
    # entre terminales Android, Linux y otras plataformas.
    title="${WHITE}${B}AWS CLOUDFRONT MANAGER${R}"
    subtitle="${GRAY}DASHBOARD DE ADMINISTRACION${R}"

    printf '\n'

    box_top "$CYAN"
    box_row "$CYAN" ""
    box_row "$CYAN" "$(center_text "$title" "$BOX_CONTENT")"
    box_row "$CYAN" "$(center_text "$subtitle" "$BOX_CONTENT")"
    box_row "$CYAN" ""
    box_bottom "$CYAN"

    printf '\n'
}

# ────────────────────────────────────────────────────────────────
# BARRA DE ESTADO
# ────────────────────────────────────────────────────────────────

status_bar() {
    local status_text
    local version_text
    local status_width
    local version_width
    local spaces
    local available_width

    # Los estados dentro del marco utilizan caracteres de
    # ancho predecible para mantener la alineación.
    if ((CF_STATS_OK == 1 && ACM_STATS_OK == 1)); then
        status_text="${GREEN}OK AWS conectado${R}"
    elif ((CF_STATS_OK == 1 || ACM_STATS_OK == 1)); then
        status_text="${YELLOW}! Datos parciales de AWS${R}"
    else
        status_text="${RED}X AWS sin datos${R}"
    fi

    version_text="${YELLOW}${VERSION}${R}"

    status_width="$(visible_width "$status_text")"
    version_width="$(visible_width "$version_text")"

    available_width=$((BOX_CONTENT - status_width - version_width))
    ((available_width < 0)) && available_width=0

    spaces="$(repeat_char ' ' "$available_width")"

    box_top "$GRAY"
    box_row "$GRAY" "${status_text}${spaces}${version_text}"
    box_bottom "$GRAY"
}

# ────────────────────────────────────────────────────────────────
# TÍTULOS DE SECCIÓN
# ────────────────────────────────────────────────────────────────

section_title() {
    printf '\n%b\n' "${BLUE}${B}  ◈ $1${R}"
}

# ────────────────────────────────────────────────────────────────
# DASHBOARD: CUATRO TARJETAS
# ────────────────────────────────────────────────────────────────

dashboard_cards() {
    local gap

    gap="$(repeat_char ' ' "$CARD_GAP")"

    # Primera fila: distribuciones y operativas.
    printf '  '
    card_border "$BLUE" top
    printf '%s' "$gap"
    card_border "$GREEN" top
    printf '\n'

    printf '  '
    card_row "$BLUE" "${BLUE}* Distribuciones${R}"
    printf '%s' "$gap"
    card_row "$GREEN" "${GREEN}+ Operativas${R}"
    printf '\n'

    printf '  '
    card_row "$BLUE" "${WHITE}${B}${TOTAL_DISTRIBUTIONS}${R}"
    printf '%s' "$gap"
    card_row "$GREEN" "${WHITE}${B}${ENABLED_DISTRIBUTIONS}${R}"
    printf '\n'

    printf '  '
    card_border "$BLUE" bottom
    printf '%s' "$gap"
    card_border "$GREEN" bottom
    printf '\n\n'

    # Segunda fila: deshabilitadas y certificados.
    printf '  '
    card_border "$YELLOW" top
    printf '%s' "$gap"
    card_border "$MAGENTA" top
    printf '\n'

    printf '  '
    card_row "$YELLOW" "${YELLOW}- Deshabilitadas${R}"
    printf '%s' "$gap"
    card_row "$MAGENTA" "${MAGENTA}# Certificados SSL${R}"
    printf '\n'

    printf '  '
    card_row "$YELLOW" "${WHITE}${B}${DISABLED_DISTRIBUTIONS}${R}"
    printf '%s' "$gap"
    card_row "$MAGENTA" "${WHITE}${B}${SSL_CERTIFICATES}${R}"
    printf '\n'

    printf '  '
    card_border "$YELLOW" bottom
    printf '%s' "$gap"
    card_border "$MAGENTA" bottom
    printf '\n\n'

    # Estado de conexión.
    if ((CF_STATS_OK == 1 && ACM_STATS_OK == 1)); then
        printf '%b\n' "${GREEN}  ✔ ${AWS_CONNECTION_STATUS}${R}"
    else
        printf '%b\n' "${YELLOW}  ⚠ ${AWS_CONNECTION_STATUS}${R}"
    fi

    # Información de CloudFront.
    if ((CF_STATS_OK == 1)); then
        printf '%b\n' \
            "${GRAY}  ℹ Operativas = habilitadas y estado Deployed.${R}"

        printf '%b\n' \
            "${GRAY}  ℹ En despliegue: ${ENABLED_PENDING_DISTRIBUTIONS}.${R}"
    else
        printf '%b\n' \
            "${YELLOW}  ⚠ No se pudieron obtener las estadísticas de CloudFront.${R}"
    fi

    # Información de ACM.
    if ((ACM_STATS_OK == 1)); then
        printf '%b\n' \
            "${GRAY}  ℹ Certificados = ACM emitidos en ${AWS_ACM_REGION}.${R}"
    else
        printf '%b\n' \
            "${YELLOW}  ⚠ No se pudieron consultar los certificados de ACM.${R}"
    fi
}

# ────────────────────────────────────────────────────────────────
# MENÚ PRINCIPAL
# ────────────────────────────────────────────────────────────────

dashboard() {
    load_aws_statistics || true

    header
    status_bar

    section_title "RESUMEN DEL SISTEMA"

    dashboard_cards

    printf '\n'
    line

    section_title "CENTRO DE CONTROL"

    box_top "$CYAN"

    # Se eliminan los emojis dentro del marco para garantizar
    # que las filas tengan siempre el mismo ancho.
    box_row "$CYAN" "${YELLOW}[1]${R}  Crear distribucion"
    box_row "$CYAN" "${YELLOW}[2]${R}  Ver estado de distribuciones"
    box_row "$CYAN" "${YELLOW}[3]${R}  Editar distribucion"
    box_row "$CYAN" "${YELLOW}[4]${R}  Activar / Desactivar distribucion"
    box_row "$CYAN" "${YELLOW}[5]${R}  Eliminar distribucion"

    box_row "$CYAN" ""
    box_separator "$CYAN"
    box_row "$CYAN" ""

    box_row "$CYAN" "${YELLOW}[6]${R}  Crear certificado SSL"
    box_row "$CYAN" "${YELLOW}[7]${R}  Remover el panel"
    box_row "$CYAN" "${YELLOW}[8]${R}  Salir"

    box_bottom "$CYAN"

    printf '\n'

    printf '%b\n' \
        "${GRAY}  AWS CloudFront - Administracion - Seguridad SSL${R}"

    printf '\n'

    printf '%b' "${CYAN}${B}  > Selecciona una opcion [1-8]: ${R}"
}

# ────────────────────────────────────────────────────────────────
# EJECUCIÓN DE MÓDULOS REMOTOS
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
    printf '%b\n' "${CYAN}⟳ Descargando módulo: ${WHITE}${module}${R}"

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
            if rm -f -- "$BIN_PATH"; then
                printf '\n%b\n' \
                    "${GREEN}✔ Comando aws-manager eliminado.${R}"

                printf '%b\n' \
                    "${GRAY}Los recursos de AWS permanecen intactos.${R}"
            else
                printf '\n%b\n' \
                    "${RED}✖ No se pudo eliminar el comando.${R}"
                pause
            fi
            exit 0
            ;;

        *)
            printf '\n%b\n' "${GRAY}Desinstalación cancelada.${R}"
            pause
            ;;
    esac
}

# ────────────────────────────────────────────────────────────────
# MENÚ Y CONTROL DE OPCIONES
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
                    "${GREEN}${B}Gracias por utilizar AWS Manager${R}"

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
