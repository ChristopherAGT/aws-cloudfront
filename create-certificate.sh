#!/bin/bash

clear

set -euo pipefail

# === Estilo de colores con tput ===
GREEN=$(tput setaf 2)
RED=$(tput setaf 1)
YELLOW=$(tput setaf 3)
BLUE=$(tput setaf 4)
MAGENTA=$(tput setaf 5)
CYAN=$(tput setaf 6)
RESET=$(tput sgr0)
BOLD=$(tput bold)

print_line() {
    echo "${MAGENTA}-------------------------------------------------------------------------------${RESET}"
}

# === Validar entorno AWS CLI ===
if ! command -v aws &>/dev/null; then
    echo -e "${RED}❌ AWS CLI no está instalado. Instálalo antes de continuar.${RESET}"
    exit 1
fi

if ! aws sts get-caller-identity &>/dev/null; then
    echo -e "${RED}❌ Las credenciales de AWS no están configuradas o son inválidas.${RESET}"
    exit 1
fi

# === Spinner usando archivo temporal como señal ===
SPINNER_FILE=$(mktemp)

start_spinner() {
    local delay=0.1
    local spinstr='|/-\'
    while [ -f "$SPINNER_FILE" ]; do
        local temp=${spinstr#?}
        printf " [%c] ${YELLOW}Esperando actualización del estado del certificado...${RESET}  " "$spinstr"
        spinstr=$temp${spinstr%"$temp"}
        sleep $delay
        printf "\r"
    done
    printf "\r\033[K"
    echo -ne "\r"
}

# === Inicio ===
echo -e "${BOLD}${CYAN}🚀 Solicitud de certificado SSL ACM (Wildcard)${RESET}"
print_line

# === Validación de dominio ===
while true; do
    read -p "🌐 Ingresa el dominio raíz (ej: ackerman.com): " DOMAIN
    if [[ -z "$DOMAIN" ]]; then
        echo -e "${RED}❌ Error: El dominio no puede estar vacío.${RESET}"
    else
        break
    fi
done

WILDCARD="*.$DOMAIN"
REGION="us-east-1"

echo -e "${BLUE}📡 Solicitando certificado para ${BOLD}$WILDCARD${RESET}..."

CERT_ARN=$(aws acm request-certificate \
  --domain-name "$WILDCARD" \
  --validation-method DNS \
  --region "$REGION" \
  --output text \
  --query CertificateArn)

if [[ -z "$CERT_ARN" ]]; then
    echo -e "${RED}❌ No se pudo solicitar el certificado.${RESET}"
    exit 1
fi

echo -e "${GREEN}✅ Certificado solicitado con ARN:${RESET}"
echo -e "${CYAN}$CERT_ARN${RESET}"

# === Obtener los datos de validación con reintentos ===
echo -e "\n⏳ Esperando datos de validación del certificado..."
for i in {1..10}; do
    VALIDATION_JSON=$(aws acm describe-certificate \
        --certificate-arn "$CERT_ARN" \
        --region "$REGION" \
        --query "Certificate.DomainValidationOptions[0].ResourceRecord" \
        --output json 2>/dev/null || true)

    CNAME_NAME=$(echo "$VALIDATION_JSON" | jq -r '.Name // empty')
    CNAME_VALUE=$(echo "$VALIDATION_JSON" | jq -r '.Value // empty')

    if [[ -n "$CNAME_NAME" && -n "$CNAME_VALUE" ]]; then
        break
    fi

    sleep 5
done

if [[ -z "$CNAME_NAME" || -z "$CNAME_VALUE" ]]; then
    echo -e "${RED}❌ No se pudieron obtener los datos de validación DNS (CNAME).${RESET}"
    echo -e "${YELLOW}ℹ️ Es posible que el certificado aún esté siendo procesado. Intenta de nuevo más tarde.${RESET}"
    exit 1
fi

DIVIDER="${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
echo -e "\n$DIVIDER"
echo -e "${BOLD}${GREEN}🔐  Registro DNS para validación del certificado (CNAME)${RESET}"
echo -e "$DIVIDER"
echo -e "${BOLD}${BLUE}📛 Nombre (CNAME):${RESET}"
echo -e "   ${CNAME_NAME}\n"
echo -e "${BOLD}${BLUE}📥 Valor (CNAME):${RESET}"
echo -e "   ${CNAME_VALUE}\n"
echo -e "$DIVIDER"
echo -e "${YELLOW}📌 Agrega estos valores en la configuración DNS de tu dominio.${RESET}"
echo -e "$DIVIDER"

# === Espera del usuario ===
while true; do
    echo ""
    read -p "$(echo -e "${CYAN}🛠️  ¿Ya configuraste el CNAME en tu DNS? (s/n): ${RESET}")" ANSWER
    case "$ANSWER" in
        [sS])
            echo -e "${GREEN}✅ Continuando con la validación...${RESET}"
            break
            ;;
        [nN])
            echo -e "${YELLOW}⏳ Tómate tu tiempo.${RESET}"
            ;;
        *)
            echo -e "${RED}❌ Respuesta inválida. Usa 's' para sí o 'n' para no.${RESET}"
            ;;
    esac
done

# === Iniciar validación del certificado ===
echo -e "\n⏳ Verificando estado del certificado..."

start_spinner & SPINNER_PID=$!

check_cert_status() {
    for i in {1..30}; do
        STATUS=$(aws acm describe-certificate \
            --certificate-arn "$CERT_ARN" \
            --region "$REGION" \
            --query "Certificate.Status" \
            --output text 2>/dev/null || echo "UNKNOWN")

        if [[ "$STATUS" == "ISSUED" || "$STATUS" == "FAILED" ]]; then
            break
        fi
        sleep 10
    done
}

check_cert_status
rm -f "$SPINNER_FILE"  # Detiene el spinner
wait $SPINNER_PID 2>/dev/null || true

# === Verificar estado final ===
STATUS=$(aws acm describe-certificate \
  --certificate-arn "$CERT_ARN" \
  --region "$REGION" \
  --query "Certificate.Status" \
  --output text)

if [[ "$STATUS" == "ISSUED" ]]; then
    echo -e "${GREEN}✅ El certificado ha sido emitido exitosamente.${RESET}"
elif [[ "$STATUS" == "FAILED" ]]; then
    echo -e "${RED}❌ La emisión del certificado falló. Verifica los registros DNS.${RESET}"
    exit 1
else
    echo -e "${YELLOW}⚠️ El certificado aún no ha sido emitido. Intenta más tarde.${RESET}"
    exit 1
fi

# === Fin del script ===
print_line
echo -e "${BOLD}${CYAN}🎉 Proceso completado.${RESET}"
print_line
