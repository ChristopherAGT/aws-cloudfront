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
VERSION="v1.1"

AWS_REGION="us-east-1"
AWS_ACM_REGION="${AWS_ACM_REGION:-us-east-1}"

TOTAL_DISTRIBUTIONS="N/D"
ENABLED_DISTRIBUTIONS="N/D"
DISABLED_DISTRIBUTIONS="N/D"
SSL_CERTIFICATES="N/D"

AWS_CONNECTION_STATUS="Sin verificar"
CF_STATS_OK=0
ACM_STATS_OK=0
ENABLED_PENDING_DISTRIBUTIONS="N/D"

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
# MEDICIÓN DE ANCHO VISIBLE
# ────────────────────────────────────────────────────────────────

visible_width() {
    local value="$1"
    local clean

    clean="$(printf '%b' "$value" |
        sed -E $'s/\033\\[[0-9;?]*[[:alpha:]]//g')"

    printf '%s' "$clean" |
        awk '
        BEGIN { width = 0 }
        {
            for (i = 1; i <= length($0); i++) {
                c = substr($0, i, 1)

                if (c ~ /[☁🟢🟡🔐🚀📊⚙️🔄🗑️🧹🚪✔✖⚠❯ℹ◈]/) {
                    width += 2
                } else {
                    width += 1
                }
            }
        }
        END { print width }
        '
}

strip_ansi() {
    printf '%b' "$1" |
        sed -E $'s/\033\\[[0-9;?]*[[:alpha:]]//g'
}

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

# ────────────────────────────────────────────────────────────────
# FILAS DE CUADROS
# ────────────────────────────────────────────────────────────────

box_row() {
    local color="$1"
    local content="$2"
    local max_width=$((BOX_INNER - 2))
    local width
    local padding
    local clean

    width="$(visible_width "$content")"

    if ((width > max_width)); then
        clean="$(strip_ansi "$content")"
        content="${clean:0:max_width}"
        width="$(visible_width "$content")"
    fi

    padding=$((max_width - width))

    printf '%b│%b%b%s%*s%b│%b\n' \
        "$color" "$R" \
        " " "$content" "$padding" "" \
        "$color" "$R"
}

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

box_separator() {
    local color="$1"
    local horizontal

    horizontal="$(repeat_char '─' "$BOX_INNER")"
    printf '%b  ├%s┤%b\n' "$color" "$horizontal" "$R"
}

center_text() {
    local content="$1"
    local total="$2"
    local width
    local left
    local right

    width="$(visible_width "$content")"

    if ((width >= total)); then
        printf '%s' "$content"
        return
    fi

    left=$(((total - width) / 2))
    right=$((total - width - left))

    printf '%*s%b%*s' "$left" "" "$content" "$right" ""
}

# ────────────────────────────────────────────────────────────────
# TARJETAS
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

card_row() {
    local color="$1"
    local content="$2"
    local max_width="$CARD_INNER"
    local width
    local padding
    local clean

    width="$(visible_width "$content")"

    if ((width > max_width)); then
        clean="$(strip_ansi "$content")"
        content="${clean:0:max_width}"
        width="$(visible_width "$content")"
    fi

    padding=$((max_width - width))

    printf '%b│%b %s%*s%b│%b' \
        "$color" "$R" \
        "$content" "$padding" "" \
        "$color" "$R"
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

    # Si el panel ya se ejecuta desde su ubicación instalada,
    # continuar normalmente sin reinstalar ni crear copias.
    if [[ -n "$resolved_source" &&
          -n "$resolved_bin" &&
          "$resolved_source" == "$resolved_bin" ]]; then
        return 0
    fi

    # Verificar que exista el archivo de origen.
    if [[ ! -f "$source_path" ]]; then
        printf '%b\n' "${RED}✖ No se encuentra el archivo del panel.${R}"
        exit 1
    fi

    # Crear el directorio de instalación si no existe.
    if ! mkdir -p -- "$BIN_DIR"; then
        printf '%b\n' "${RED}✖ No se pudo crear ${BIN_DIR}.${R}"
        exit 1
    fi

    # Crear un archivo temporal en el mismo directorio.
    # Esto permite reemplazar el ejecutable sin generar respaldos.
    temp_install="$(mktemp "${BIN_DIR}/.aws-manager.XXXXXX" 2>/dev/null)" || {
        printf '%b\n' "${RED}✖ No se pudo crear el archivo temporal.${R}"
        exit 1
    }

    # Copiar la nueva versión al archivo temporal.
    if ! cp -- "$source_path" "$temp_install"; then
        rm -f -- "$temp_install"
        printf '%b\n' "${RED}✖ No se pudo preparar la nueva versión.${R}"
        exit 1
    fi

    # Establecer permisos antes de reemplazar el ejecutable.
    if ! chmod 700 "$temp_install"; then
        rm -f -- "$temp_install"
        printf '%b\n' "${RED}✖ No se pudieron establecer los permisos.${R}"
        exit 1
    fi

    # Sustituir el ejecutable anterior.
    # Al utilizar mv dentro del mismo sistema de archivos,
    # se evita sobrescribir directamente el archivo en ejecución.
    if ! mv -f -- "$temp_install" "$BIN_PATH"; then
        rm -f -- "$temp_install"
        printf '%b\n' "${RED}✖ No se pudo instalar aws-manager.${R}"
        exit 1
    fi

    printf '\n%b\n' "${GREEN}✔ AWS Manager actualizado correctamente.${R}"
    printf '%b\n\n' "${GRAY}Comando: ${BIN_PATH}${R}"

    # Ejecutar la versión recién instalada.
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
    command -v sed >/dev/null 2>&1 || missing+=("sed")
    command -v awk >/dev/null 2>&1 || missing+=("awk")
    command -v jq >/dev/null 2>&1 || missing+=("jq")
    command -v aws >/dev/null 2>&1 || missing+=("aws-cli")
    command -v mktemp >/dev/null 2>&1 || missing+=("mktemp")

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

    # ────────────────────────────────────────────────────────────
    # VERIFICAR CREDENCIALES
    # ────────────────────────────────────────────────────────────

    if ! aws sts get-caller-identity \
        --output json >/dev/null 2>&1; then

        AWS_CONNECTION_STATUS="Error de autenticación"
        return 1
    fi

    # ────────────────────────────────────────────────────────────
    # CONSULTAR DISTRIBUCIONES CLOUDFRONT
    # ────────────────────────────────────────────────────────────

    if ! distributions_json="$(
        aws cloudfront list-distributions \
            --output json 2>/dev/null
    )"; then

        AWS_CONNECTION_STATUS="Error consultando CloudFront"
    else
        if printf '%s' "$distributions_json" |
            jq -e '
                (.DistributionList.Items // [])
                | type == "array"
            ' >/dev/null 2>&1; then

            # Contar directamente los elementos de Items.
            # No depender de DistributionList.Quantity.

            total="$(
                printf '%s' "$distributions_json" |
                jq -r '
                    (.DistributionList.Items // [])
                    | length
                '
            )"

            # Distribuciones habilitadas y desplegadas.
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

            # Distribuciones deshabilitadas.
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

            # Distribuciones habilitadas cuyo despliegue
            # todavía no ha terminado.
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

            # Validar que los resultados sean números enteros.
            if [[ "$total" =~ ^[0-9]+$ &&
                  "$enabled" =~ ^[0-9]+$ &&
                  "$disabled" =~ ^[0-9]+$ &&
                  "$enabled_pending" =~ ^[0-9]+$ ]]; then

                TOTAL_DISTRIBUTIONS="$total"
                ENABLED_DISTRIBUTIONS="$enabled"
                DISABLED_DISTRIBUTIONS="$disabled"
                ENABLED_PENDING_DISTRIBUTIONS="$enabled_pending"

                CF_STATS_OK=1
            else
                AWS_CONNECTION_STATUS="Datos inválidos de CloudFront"
            fi
        else
            AWS_CONNECTION_STATUS="Respuesta de CloudFront inválida"
        fi
    fi

    # ────────────────────────────────────────────────────────────
    # CONSULTAR CERTIFICADOS SSL DE ACM
    # ────────────────────────────────────────────────────────────

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

    # ────────────────────────────────────────────────────────────
    # ESTADO FINAL DE LAS CONSULTAS
    # ────────────────────────────────────────────────────────────

    if ((CF_STATS_OK == 1 && ACM_STATS_OK == 1)); then
        AWS_CONNECTION_STATUS="Conectado a AWS"

    elif ((CF_STATS_OK == 1 && ACM_STATS_OK == 0)); then
        AWS_CONNECTION_STATUS="CloudFront OK; error en ACM"

    elif ((CF_STATS_OK == 0 && ACM_STATS_OK == 1)); then
        AWS_CONNECTION_STATUS="ACM OK; error en CloudFront"

    else
        AWS_CONNECTION_STATUS="Error consultando AWS"
    fi

    if ((CF_STATS_OK == 1 && ACM_STATS_OK == 1)); then
        return 0
    fi

    return 1
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

    if ((CF_STATS_OK == 1 && ACM_STATS_OK == 1)); then
        status="${GREEN}✔ AWS conectado${R}                         ${YELLOW}${VERSION}${R}"
    elif ((CF_STATS_OK == 1 || ACM_STATS_OK == 1)); then
        status="${YELLOW}⚠ Datos parciales de AWS${R}                ${YELLOW}${VERSION}${R}"
    else
        status="${RED}✖ AWS sin datos${R}                         ${YELLOW}${VERSION}${R}"
    fi

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
# ────────────────────────────────────────────────────────────────

dashboard_cards() {
    local gap

    gap="$(repeat_char ' ' "$CARD_GAP")"

    # FILA 1: BORDES SUPERIORES

    card_border "$BLUE" top
    printf '%s' "$gap"
    card_border "$GREEN" top
    printf '\n'

    # FILA 1: TÍTULOS

    card_row "$BLUE" "☁ ${BLUE}Distribuciones${R}"
    printf '%s' "$gap"
    card_row "$GREEN" "🟢 ${GREEN}Operativas${R}"
    printf '\n'

    # FILA 1: VALORES

    card_row "$BLUE" "${WHITE}${B}${TOTAL_DISTRIBUTIONS}${R}"
    printf '%s' "$gap"
    card_row "$GREEN" "${WHITE}${B}${ENABLED_DISTRIBUTIONS}${R}"
    printf '\n'

    # FILA 1: BORDES INFERIORES

    card_border "$BLUE" bottom
    printf '%s' "$gap"
    card_border "$GREEN" bottom
    printf '\n\n'

    # FILA 2: BORDES SUPERIORES

    card_border "$YELLOW" top
    printf '%s' "$gap"
    card_border "$MAGENTA" top
    printf '\n'

    # FILA 2: TÍTULOS

    card_row "$YELLOW" "🟡 ${YELLOW}Deshabilitadas${R}"
    printf '%s' "$gap"
    card_row "$MAGENTA" "🔐 ${MAGENTA}Certificados SSL${R}"
    printf '\n'

    # FILA 2: VALORES

    card_row "$YELLOW" "${WHITE}${B}${DISABLED_DISTRIBUTIONS}${R}"
    printf '%s' "$gap"
    card_row "$MAGENTA" "${WHITE}${B}${SSL_CERTIFICATES}${R}"
    printf '\n'

    # FILA 2: BORDES INFERIORES

    card_border "$YELLOW" bottom
    printf '%s' "$gap"
    card_border "$MAGENTA" bottom
    printf '\n\n'

    # ESTADO DE CONEXIÓN

    if ((CF_STATS_OK == 1 && ACM_STATS_OK == 1)); then
        printf '%b\n' "${GREEN}  ✔ ${AWS_CONNECTION_STATUS}${R}"
    else
        printf '%b\n' "${YELLOW}  ⚠ ${AWS_CONNECTION_STATUS}${R}"
    fi

    # INFORMACIÓN DE CLOUDFRONT

    if ((CF_STATS_OK == 1)); then
        printf '%b\n' \
            "${GRAY}  ℹ Operativas = habilitadas y estado Deployed.${R}"

        printf '%b\n' \
            "${GRAY}  ℹ En despliegue: ${ENABLED_PENDING_DISTRIBUTIONS}.${R}"
    else
        printf '%b\n' \
            "${YELLOW}  ⚠ No se pudieron obtener las estadísticas de CloudFront.${R}"
    fi

    # INFORMACIÓN DE ACM

    if ((ACM_STATS_OK == 1)); then
        printf '%b\n' \
            "${GRAY}  ℹ Certificados = ACM emitidos en ${AWS_ACM_REGION}.${R}"
    else
        printf '%b\n' \
            "${YELLOW}  ⚠ No se pudieron consultar los certificados de ACM.${R}"
    fi
}

# ────────────────────────────────────────────────────────────────
# MENÚ PRINCIPAL VISUAL
# ────────────────────────────────────────────────────────────────

dashboard() {
    # Actualizar estadísticas antes de dibujar el panel.
    # Si una consulta falla, las demás pueden seguir funcionando.
    load_aws_statistics || true

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
