#!/usr/bin/env bash

# ==============================================================
# LINUX CLEANUP MANAGER
# Limpieza, mantenimiento y diagnóstico del sistema
# Versión: v1.2
# Compatible con Debian / Ubuntu
# ==============================================================

set -o pipefail
export LC_ALL=C.UTF-8

VERSION="v1.2"
BOX_WIDTH=58
TMP_MAX_AGE=1440
LOG_FILE="/var/log/cleanup-manager.log"

# --------------------------------------------------------------
# COLORES
# --------------------------------------------------------------

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
    R='' B='' D='' RED='' GREEN=''
    YELLOW='' BLUE='' MAGENTA=''
    CYAN='' WHITE='' GRAY=''
fi

# --------------------------------------------------------------
# VARIABLES
# --------------------------------------------------------------

declare -a STEP_NAMES=()
declare -a STEP_RESULTS=()
declare -a STEP_DETAILS=()

TOTAL_OK=0
TOTAL_FAIL=0
TOTAL_SKIP=0

START_TIME=0

MEM_BEFORE=0
MEM_AFTER=0
CACHE_BEFORE=0
CACHE_AFTER=0
DISK_BEFORE=0
DISK_AFTER=0
APT_BEFORE=0
APT_AFTER=0
TMP_BEFORE=0
TMP_AFTER=0

JOURNAL_FREED="0 B"

# --------------------------------------------------------------
# UTILIDADES
# --------------------------------------------------------------

repeat_char() {
    local char="$1"
    local count="$2"
    local result=""

    (( count < 0 )) && count=0

    printf -v result '%*s' "$count" ''
    result="${result// /$char}"

    printf '%s' "$result"
}

visible_width() {
    local text="$1"

    # Retira códigos ANSI de color antes de medir el texto.
    text="$(printf '%s' "$text" |
        sed -E $'s/\033\\[[0-9;]*[[:alpha:]]//g')"

    printf '%s' "${#text}"
}

format_bytes() {
    local bytes="${1:-0}"

    [[ "$bytes" =~ ^[0-9]+$ ]] || bytes=0

    awk -v b="$bytes" 'BEGIN {
        if (b >= 1073741824)
            printf "%.2f GiB", b / 1073741824
        else if (b >= 1048576)
            printf "%.2f MiB", b / 1048576
        else if (b >= 1024)
            printf "%.2f KiB", b / 1024
        else
            printf "%.0f B", b
    }'
}

safe_number() {
    local number="${1:-0}"

    if [[ "$number" =~ ^[0-9]+$ ]]; then
        printf '%s\n' "$number"
    else
        printf '0\n'
    fi
}

read_meminfo() {
    local key="$1"

    awk -v key="$key" '
        $1 == key ":" {
            print $2 * 1024
            found=1
            exit
        }
        END {
            if (!found) print 0
        }
    ' /proc/meminfo
}

read_disk_used() {
    df -B1 --output=used / 2>/dev/null |
        awk 'NR == 2 {print $1; exit}'
}

read_disk_available() {
    df -B1 --output=avail / 2>/dev/null |
        awk 'NR == 2 {print $1; exit}'
}

read_disk_total() {
    df -B1 --output=size / 2>/dev/null |
        awk 'NR == 2 {print $1; exit}'
}

read_directory_size() {
    local directory="$1"

    if [[ -d "$directory" ]]; then
        du -sb "$directory" 2>/dev/null |
            awk 'NR == 1 {print $1; exit}'
    else
        printf '0\n'
    fi
}

# --------------------------------------------------------------
# CUADROS ALINEADOS
# --------------------------------------------------------------

box_top() {
    local color="$1"
    local line

    line="$(repeat_char '─' "$BOX_WIDTH")"
    printf '%b  ╭%s╮%b\n' "$color" "$line" "$R"
}

box_bottom() {
    local color="$1"
    local line

    line="$(repeat_char '─' "$BOX_WIDTH")"
    printf '%b  ╰%s╯%b\n' "$color" "$line" "$R"
}

box_separator() {
    local color="$1"
    local line

    line="$(repeat_char '─' "$BOX_WIDTH")"
    printf '%b  ├%s┤%b\n' "$color" "$line" "$R"
}

box_row() {
    local color="$1"
    local content="$2"
    local width padding

    # Calcula el ancho visible sin contar los colores ANSI.
    width="$(visible_width "$content")"

    # Evita que una fila sobrepase los bordes.
    if (( width > BOX_WIDTH - 2 )); then
        content="${content:0:$((BOX_WIDTH - 5))}..."
        width="$(visible_width "$content")"
    fi

    # Una columna de margen a cada lado del contenido.
    padding=$((BOX_WIDTH - width - 2))
    (( padding < 0 )) && padding=0

    # Corrección: el borde derecho se imprime inmediatamente
    # después del espacio final, sin desplazarlo una columna.
    printf '%b  │%b %s%*s %b│%b\n' \
        "$color" "$R" "$content" "$padding" "" "$color" "$R"
}

center_text() {
    local content="$1"
    local available="$2"
    local width left right

    width="$(visible_width "$content")"

    if (( width >= available )); then
        printf '%s' "$content"
        return
    fi

    left=$(((available - width) / 2))
    right=$((available - width - left))

    printf '%*s%b%*s' "$left" "" "$content" "$right" ""
}

# --------------------------------------------------------------
# REGISTRO
# --------------------------------------------------------------

log_message() {
    printf '[%s] %s\n' \
        "$(date '+%F %T')" "$*" >> "$LOG_FILE" 2>/dev/null || true
}

record_result() {
    local name="$1"
    local result="$2"
    local detail="$3"

    STEP_NAMES+=("$name")
    STEP_RESULTS+=("$result")
    STEP_DETAILS+=("$detail")

    case "$result" in
        OK)   ((TOTAL_OK += 1)) ;;
        FAIL) ((TOTAL_FAIL += 1)) ;;
        SKIP) ((TOTAL_SKIP += 1)) ;;
    esac

    log_message "$result | $name | $detail"
}

# --------------------------------------------------------------
# EJECUCIÓN DE OPERACIONES
# --------------------------------------------------------------

run_step() {
    local name="$1"
    shift

    local output rc

    printf '\n%b  ⚙ %s%b\n' "$CYAN" "$name" "$R"

    output="$("$@" 2>&1)"
    rc=$?

    if (( rc == 0 )); then
        printf '%b  ✔ Completado%b\n' "$GREEN" "$R"
        record_result "$name" "OK" "Completada"
    else
        printf '%b  ✖ Error (código %s)%b\n' "$RED" "$rc" "$R"

        if [[ -n "$output" ]]; then
            printf '%b%s%b\n' "$GRAY" "$output" "$R"
        fi

        record_result "$name" "FAIL" "Código $rc"
    fi

    if [[ -n "$output" ]]; then
        {
            printf '\n[%s] %s | código=%s\n' \
                "$(date '+%F %T')" "$name" "$rc"
            printf '%s\n' "$output"
        } >> "$LOG_FILE" 2>/dev/null || true
    fi

    return 0
}

# --------------------------------------------------------------
# ENCABEZADO
# --------------------------------------------------------------

header() {
    clear 2>/dev/null || true

    printf '\n'
    box_top "$CYAN"
    box_row "$CYAN" ""
    box_row "$CYAN" "$(center_text "${WHITE}${B}LINUX CLEANUP MANAGER${R}" "$((BOX_WIDTH - 2))")"
    box_row "$CYAN" "$(center_text "${GRAY}LIMPIEZA Y DIAGNOSTICO DEL SISTEMA${R}" "$((BOX_WIDTH - 2))")"
    box_row "$CYAN" ""
    box_bottom "$CYAN"

    printf '\n'
    box_top "$GRAY"
    box_row "$GRAY" "${GREEN}● Sistema listo${R}                         ${YELLOW}${VERSION}${R}"
    box_bottom "$GRAY"
}

# --------------------------------------------------------------
# INFORMACIÓN DEL SISTEMA
# --------------------------------------------------------------

show_system_info() {
    local total available used swap_total swap_free
    local disk_total disk_free disk_used
    local mem_pct disk_pct swap_used hostname os_name uptime_text
    local ram_status disk_status

    total="$(safe_number "$(read_meminfo MemTotal)")"
    available="$(safe_number "$(read_meminfo MemAvailable)")"
    used=$((total - available))

    swap_total="$(safe_number "$(read_meminfo SwapTotal)")"
    swap_free="$(safe_number "$(read_meminfo SwapFree)")"
    swap_used=$((swap_total - swap_free))

    disk_total="$(safe_number "$(read_disk_total)")"
    disk_free="$(safe_number "$(read_disk_available)")"
    disk_used="$(safe_number "$(read_disk_used)")"

    mem_pct=0
    disk_pct=0

    (( total > 0 )) &&
        mem_pct=$((used * 100 / total))

    (( disk_total > 0 )) &&
        disk_pct=$((disk_used * 100 / disk_total))

    hostname="$(hostname 2>/dev/null || printf 'Desconocido')"

    os_name="Linux"
    if [[ -r /etc/os-release ]]; then
        os_name="$(. /etc/os-release; printf '%s' "${PRETTY_NAME:-Linux}")"
    fi

    uptime_text="$(uptime -p 2>/dev/null || printf 'No disponible')"

    if (( mem_pct >= 90 )); then
        ram_status="${RED}Alto${R}"
    elif (( mem_pct >= 75 )); then
        ram_status="${YELLOW}Moderado${R}"
    else
        ram_status="${GREEN}Normal${R}"
    fi

    if (( disk_pct >= 90 )); then
        disk_status="${RED}Crítico${R}"
    elif (( disk_pct >= 75 )); then
        disk_status="${YELLOW}Elevado${R}"
    else
        disk_status="${GREEN}Normal${R}"
    fi

    printf '\n'
    printf '%b  📊 INFORMACIÓN DEL SISTEMA%b\n' "$BLUE" "$R"

    box_top "$BLUE"
    box_row "$BLUE" "${WHITE}${B}EQUIPO${R}"
    box_separator "$BLUE"
    box_row "$BLUE" "Host:       $hostname"
    box_row "$BLUE" "Sistema:    $os_name"
    box_row "$BLUE" "Encendido:  $uptime_text"
    box_bottom "$BLUE"

    printf '\n'
    box_top "$CYAN"
    box_row "$CYAN" "${WHITE}${B}MEMORIA RAM${R}"
    box_separator "$CYAN"
    box_row "$CYAN" "Total:       $(format_bytes "$total")"
    box_row "$CYAN" "Utilizada:   $(format_bytes "$used") (${mem_pct}%)"
    box_row "$CYAN" "Disponible:  $(format_bytes "$available")"
    box_row "$CYAN" "Estado:      $ram_status"
    box_bottom "$CYAN"

    printf '\n'
    box_top "$MAGENTA"
    box_row "$MAGENTA" "${WHITE}${B}ALMACENAMIENTO${R}"
    box_separator "$MAGENTA"
    box_row "$MAGENTA" "Disco total:      $(format_bytes "$disk_total")"
    box_row "$MAGENTA" "Espacio usado:    $(format_bytes "$disk_used")"
    box_row "$MAGENTA" "Espacio libre:    $(format_bytes "$disk_free")"
    box_row "$MAGENTA" "Uso del disco:    ${disk_pct}%"
    box_row "$MAGENTA" "Estado:           $disk_status"
    box_bottom "$MAGENTA"

    printf '\n'
    box_top "$YELLOW"
    box_row "$YELLOW" "${WHITE}${B}MEMORIA SWAP${R}"
    box_separator "$YELLOW"
    box_row "$YELLOW" "Total:       $(format_bytes "$swap_total")"
    box_row "$YELLOW" "Utilizada:   $(format_bytes "$swap_used")"
    box_row "$YELLOW" "Libre:       $(format_bytes "$swap_free")"
    box_bottom "$YELLOW"

    printf '\n'
    printf '%b  ℹ Los valores reflejan el estado actual del sistema.%b\n' \
        "$GRAY" "$R"
}

# --------------------------------------------------------------
# COMPROBACIONES INICIALES
# --------------------------------------------------------------

check_environment() {
    local missing=()
    local cmd

    for cmd in awk sed df du date find journalctl sysctl sync \
               apt-get hostname uptime free rm; do
        command -v "$cmd" >/dev/null 2>&1 || missing+=("$cmd")
    done

    if ((${#missing[@]} > 0)); then
        printf '%b✖ Faltan comandos: %s%b\n' \
            "$RED" "${missing[*]}" "$R"
        return 1
    fi

    if [[ $EUID -ne 0 ]]; then
        printf '%b✖ Ejecuta el script como root o con sudo.%b\n' "$RED" "$R"
        printf '%b  Ejemplo: sudo bash cleanup-manager.sh%b\n' "$GRAY" "$R"
        return 1
    fi

    if ! command -v apt-get >/dev/null 2>&1; then
        printf '%b✖ Este script requiere Debian/Ubuntu con APT.%b\n' "$RED" "$R"
        return 1
    fi

    return 0
}

# --------------------------------------------------------------
# MÉTRICAS ANTES Y DESPUÉS
# --------------------------------------------------------------

capture_before() {
    MEM_BEFORE="$(safe_number "$(read_meminfo MemAvailable)")"
    CACHE_BEFORE="$(safe_number "$(read_meminfo Cached)")"
    DISK_BEFORE="$(safe_number "$(read_disk_used)")"
    APT_BEFORE="$(safe_number "$(read_directory_size /var/cache/apt/archives)")"
    TMP_BEFORE="$(safe_number "$(read_directory_size /tmp)")"
}

capture_after() {
    MEM_AFTER="$(safe_number "$(read_meminfo MemAvailable)")"
    CACHE_AFTER="$(safe_number "$(read_meminfo Cached)")"
    DISK_AFTER="$(safe_number "$(read_disk_used)")"
    APT_AFTER="$(safe_number "$(read_directory_size /var/cache/apt/archives)")"
    TMP_AFTER="$(safe_number "$(read_directory_size /tmp)")"
}

# --------------------------------------------------------------
# LIMPIEZA DE JOURNAL
# --------------------------------------------------------------

vacuum_journal() {
    local output rc

    output="$(journalctl --vacuum-time=3d 2>&1)"
    rc=$?

    printf '%s\n' "$output"

    JOURNAL_FREED="$(
        printf '%s\n' "$output" |
            sed -nE 's/.*freed ([^ ]+) of archived journals.*/\1/p' |
            tail -n 1
    )"

    [[ -n "$JOURNAL_FREED" ]] || JOURNAL_FREED="0 B"

    return "$rc"
}

# --------------------------------------------------------------
# LIMPIEZA SEGURA DE /tmp
# --------------------------------------------------------------

clean_tmp() {
    find /tmp -mindepth 1 -maxdepth 1 \
        -mmin "+${TMP_MAX_AGE}" \
        ! -name '.*' \
        -exec rm -rf -- {} +
}

# --------------------------------------------------------------
# LIMPIEZA COMPLETA
# --------------------------------------------------------------

perform_cleanup() {
    START_TIME="$(date +%s)"

    STEP_NAMES=()
    STEP_RESULTS=()
    STEP_DETAILS=()

    TOTAL_OK=0
    TOTAL_FAIL=0
    TOTAL_SKIP=0
    JOURNAL_FREED="0 B"

    capture_before

    header

    printf '\n'
    box_top "$YELLOW"
    box_row "$YELLOW" "${WHITE}${B}LIMPIEZA AUTOMATICA${R}"
    box_separator "$YELLOW"
    box_row "$YELLOW" "Se ejecutarán las tareas seguras:"
    box_row "$YELLOW" "1. Sincronizar datos pendientes"
    box_row "$YELLOW" "2. Liberar cachés recuperables del kernel"
    box_row "$YELLOW" "3. Retirar journals archivados de más de 3 días"
    box_row "$YELLOW" "4. Limpiar paquetes descargados de APT"
    box_row "$YELLOW" "5. Retirar elementos antiguos de /tmp"
    box_bottom "$YELLOW"

    printf '\n%b  🚀 Iniciando limpieza...%b\n' "$CYAN" "$R"

    run_step "Sincronización de datos" sync

    run_step "Liberación de caché del kernel" \
        sysctl -w vm.drop_caches=3

    run_step "Limpieza de journals archivados" vacuum_journal

    run_step "Limpieza de paquetes APT" apt-get clean

    run_step "Limpieza de temporales antiguos" clean_tmp

    capture_after

    show_final_report
}

# --------------------------------------------------------------
# INFORME FINAL
# --------------------------------------------------------------

show_final_report() {
    local end_time elapsed
    local mem_diff disk_diff apt_diff tmp_diff cache_diff

    end_time="$(date +%s)"
    elapsed=$((end_time - START_TIME))

    mem_diff=$((MEM_AFTER - MEM_BEFORE))
    disk_diff=$((DISK_BEFORE - DISK_AFTER))
    apt_diff=$((APT_BEFORE - APT_AFTER))
    tmp_diff=$((TMP_BEFORE - TMP_AFTER))
    cache_diff=$((CACHE_BEFORE - CACHE_AFTER))

    printf '\n\n'
    printf '%b  📋 RESUMEN DE LA LIMPIEZA%b\n' "$GREEN" "$R"

    box_top "$GREEN"
    box_row "$GREEN" "${WHITE}${B}RESULTADO DE OPERACIONES${R}"
    box_separator "$GREEN"
    box_row "$GREEN" "${GREEN}✔ Completadas: ${TOTAL_OK}${R}"
    box_row "$GREEN" "${RED}✖ Fallidas:    ${TOTAL_FAIL}${R}"
    box_row "$GREEN" "${YELLOW}↷ Omitidas:    ${TOTAL_SKIP}${R}"

    box_separator "$GREEN"
    box_row "$GREEN" "${WHITE}${B}CAMBIOS OBSERVADOS${R}"
    box_row "$GREEN" "RAM disponible antes:  $(format_bytes "$MEM_BEFORE")"
    box_row "$GREEN" "RAM disponible después: $(format_bytes "$MEM_AFTER")"

    if (( mem_diff >= 0 )); then
        box_row "$GREEN" "Variación RAM disponible: +$(format_bytes "$mem_diff")"
    else
        box_row "$GREEN" "Variación RAM disponible: -$(format_bytes "$((-mem_diff))")"
    fi

    box_row "$GREEN" "Caché de archivos antes:  $(format_bytes "$CACHE_BEFORE")"
    box_row "$GREEN" "Caché de archivos después: $(format_bytes "$CACHE_AFTER")"

    if (( disk_diff >= 0 )); then
        box_row "$GREEN" "Reducción uso de disco: +$(format_bytes "$disk_diff")"
    else
        box_row "$GREEN" "Cambio uso de disco: -$(format_bytes "$((-disk_diff))")"
    fi

    box_row "$GREEN" "Caché APT antes:  $(format_bytes "$APT_BEFORE")"
    box_row "$GREEN" "Caché APT después: $(format_bytes "$APT_AFTER")"
    box_row "$GREEN" "Cambio caché APT: $(format_bytes "$((apt_diff < 0 ? -apt_diff : apt_diff))")"

    box_row "$GREEN" "Temporales antes:  $(format_bytes "$TMP_BEFORE")"
    box_row "$GREEN" "Temporales después: $(format_bytes "$TMP_AFTER")"
    box_row "$GREEN" "Journals eliminados: ${JOURNAL_FREED}"

    box_separator "$GREEN"
    box_row "$GREEN" "Duración: ${elapsed} segundos"
    box_row "$GREEN" "Fecha: $(date '+%Y-%m-%d %H:%M:%S')"
    box_bottom "$GREEN"

    printf '\n'
    printf '%b  💡 INFORMACIÓN IMPORTANTE%b\n' "$CYAN" "$R"
    printf '%b  • La variación de RAM no equivale a memoria garantizada como liberada.%b\n' "$GRAY" "$R"
    printf '%b  • Liberar caché puede hacer que algunas operaciones posteriores sean más lentas.%b\n' "$GRAY" "$R"
    printf '%b  • Solo se intenta limpiar contenido visible y antiguo de /tmp.%b\n' "$GRAY" "$R"
    printf '%b  • Los journals archivados eliminados ya no estarán disponibles.%b\n' "$GRAY" "$R"
    printf '%b  • Registro: %s%b\n' "$GRAY" "$LOG_FILE" "$R"

    log_message "Limpieza finalizada | OK=$TOTAL_OK FAIL=$TOTAL_FAIL SKIP=$TOTAL_SKIP | duración=${elapsed}s"

    printf '\n%b  ✔ Limpieza finalizada.%b\n' "$GREEN" "$R"
}

# --------------------------------------------------------------
# MENÚ PRINCIPAL
# --------------------------------------------------------------

main() {
    local option
    local total available used disk_free disk_total mem_pct disk_pct

    if ! check_environment; then
        exit 1
    fi

    while true; do
        header

        printf '\n'
        box_top "$BLUE"
        box_row "$BLUE" "${WHITE}${B}ESTADO ACTUAL${R}"
        box_separator "$BLUE"

        total="$(safe_number "$(read_meminfo MemTotal)")"
        available="$(safe_number "$(read_meminfo MemAvailable)")"
        used=$((total - available))
        disk_free="$(safe_number "$(read_disk_available)")"
        disk_total="$(safe_number "$(read_disk_total)")"

        mem_pct=0
        disk_pct=0

        (( total > 0 )) &&
            mem_pct=$((used * 100 / total))

        (( disk_total > 0 )) &&
            disk_pct=$(((disk_total - disk_free) * 100 / disk_total))

        box_row "$BLUE" "RAM disponible: $(format_bytes "$available")"
        box_row "$BLUE" "RAM utilizada:  ${mem_pct}%"
        box_row "$BLUE" "Disco utilizado: ${disk_pct}%"
        box_row "$BLUE" "Disco libre:     $(format_bytes "$disk_free")"
        box_bottom "$BLUE"

        printf '\n'
        box_top "$CYAN"
        box_row "$CYAN" "${WHITE}${B}CENTRO DE CONTROL${R}"
        box_separator "$CYAN"
        box_row "$CYAN" "${GREEN}[1]${R}  🧹 Ejecutar limpieza completa"
        box_row "$CYAN" "${BLUE}[2]${R}  📊 Información detallada del sistema"
        box_row "$CYAN" "${RED}[3]${R}  🚪 Salir"
        box_bottom "$CYAN"

        printf '\n%b  Selecciona una opción [1-3]: %b' "$CYAN" "$R"

        if ! read -r option; then
            printf '\n'
            exit 0
        fi

        case "$option" in
            1)
                perform_cleanup
                printf '\n'
                read -r -p "Presiona ENTER para volver al menú..." _
                ;;
            2)
                header
                show_system_info
                printf '\n'
                read -r -p "Presiona ENTER para volver al menú..." _
                ;;
            3)
                printf '\n%b  👋 Hasta pronto.%b\n' "$GREEN" "$R"
                exit 0
                ;;
            *)
                printf '\n%b  ⚠ Opción inválida. Selecciona 1, 2 o 3.%b\n' "$YELLOW" "$R"
                sleep 1
                ;;
        esac
    done
}

main "$@"
