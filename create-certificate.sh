#!/bin/bash

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

# === Spinner controlado ===
start_spinner() {
    local delay=0.1
    local spinstr='|/-\'
    SPINNER_ACTIVE=true

    while $SPINNER_ACTIVE; do
        local temp=${spinstr#?}
        printf " [%c] ${YELLOW}Esperando actualización del estado del certificado...${RESET}  " "$spinstr"
        spinstr=$temp${spinstr%"$temp"}
        sleep $delay
        printf "\r"
    done
}

stop_spinner() {
    SPINNER_ACTIVE=false
    wait $SPINNER_PID 2>/dev/null
    echo -ne "\r"
}

# === Inicio ===
echo -e "${BOLD}${CYAN}🚀 Solicitud de certificado SSL ACM (Wildcard)${RESET}"
print_line

# === Validación de dominio no vacío ===
while true; do
    read -p "🌐 Ingresa el dominio raíz (ej: abysscore.xyz): " DOMAIN
    if [[ -z "$DOMAIN" ]]; then
        echo -e "${RED}❌ Error: El dominio no puede estar vacío. Intenta de nuevo.${RESET}"
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

echo -e "\n⏳ Esperando unos segundos antes de mostrar los datos de validación..."
sleep 10

VALIDATION=$(aws acm describe-certificate \
  --certificate-arn "$CERT_ARN" \
  --region "$REGION" \
  --query "Certificate.DomainValidationOptions[0].ResourceRecord" \
  --output text)

CNAME_NAME=$(echo "$VALIDATION" | awk '{print $1}')
CNAME_VALUE=$(echo "$VALIDATION" | awk '{print $3}')

# === Sección CNAME con diseño mejorado ===
DIVIDER="${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"

echo -e "\n$DIVIDER"
echo -e "${BOLD}${GREEN}🔐  Registro DNS para validación del certificado (CNAME)${RESET}"
echo -e "$DIVIDER"

echo -e "${BOLD}${BLUE}📛 Nombre (CNAME):${RESET}"
echo -e "   ${CNAME_NAME}\n"

echo -e "${BOLD}${BLUE}📥 Valor (CNAME):${RESET}"
echo -e "   ${CNAME_VALUE}\n"

echo -e "$DIVIDER"
echo -e "${YELLOW}📌 Copia ambos valores en tu proveedor de DNS (ej. Cloudflare)${RESET}"
echo -e "$DIVIDER"

# === Pregunta para continuar ===
while true; do
    echo ""
    read -p "$(echo -e "${CYAN}🛠️  ¿Ya realizaste la configuración DNS (CNAME) en tu proveedor? (s/n): ${RESET}")" ANSWER

    case "$ANSWER" in
        [sS])
            echo -e "${GREEN}✅ Continuando con la validación del certificado...${RESET}"
            break
            ;;
        [nN])
            echo -e "${YELLOW}⏳ Tómate tu tiempo. Te esperamos para continuar cuando estés listo.${RESET}"
            ;;
        *)
            echo -e "${RED}❌ Respuesta inválida. Escribe 's' para sí o 'n' para no.${RESET}"
            ;;
    esac
done

# === Validación del certificado (con spinner) ===
echo -e "\n⏳ Iniciando verificación de emisión del certificado..."

(
    for i in {1..30}; do
        STATUS=$(aws acm describe-certificate \
          --certificate-arn "$CERT_ARN" \
          --region "$REGION" \
          --query "Certificate.Status" \
          --output text)

        if [[ "$STATUS" == "ISSUED" || "$STATUS" == "FAILED" ]]; then
            break
        fi
        sleep 10
    done
) &
CHECK_PID=$!

# Spinner en segundo plano
start_spinner &
SPINNER_PID=$!

# Esperar al proceso de validación
wait $CHECK_PID
stop_spinner

# Verificar estado final del certificado
STATUS=$(aws acm describe-certificate \
  --certificate-arn "$CERT_ARN" \
  --region "$REGION" \
  --query "Certificate.Status" \
  --output text)

if [[ "$STATUS" == "ISSUED" ]]; then
    echo -e "${GREEN}✅ El certificado ha sido emitido exitosamente.${RESET}"
elif [[ "$STATUS" == "FAILED" ]]; then
    echo -e "${RED}❌ La solicitud del certificado falló. Revisa el dominio o el CNAME.${RESET}"
    exit 1
else
    echo -e "${YELLOW}⚠️ El certificado aún no se ha emitido. Verifica el CNAME en tu DNS.${RESET}"
    exit 1
fi
