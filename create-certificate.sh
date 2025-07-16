#!/bin/bash

# === Estilo visual ===
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

spinner() {
    local pid=$1
    local delay=0.1
    local spinstr='|/-\'
    while kill -0 "$pid" 2>/dev/null; do
        local temp=${spinstr#?}
        printf " [%c] ${YELLOW}Esperando actualización del estado del certificado...${RESET}  " "$spinstr"
        spinstr=$temp${spinstr%"$temp"}
        sleep $delay
        printf "\r"
    done
}

# === Inicio del script ===
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

print_line
echo -e "${BOLD}${YELLOW}🧾 Añade el siguiente CNAME en tu proveedor DNS (ej. Cloudflare):${RESET}"
print_line
printf "%-25s | %-60s\n" "${BOLD}Nombre (CNAME)${RESET}" "${BOLD}Valor (CNAME)${RESET}"
echo "--------------------------+---------------------------------------------------------------"
printf "%-25s | %-60s\n" "$CNAME_NAME" "$CNAME_VALUE"
print_line

echo -e "\n⏳ Esperando validación de dominio. Esto puede tardar varios minutos..."

# Espera con spinner mientras cambia a estado ISSUED
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
spinner $!

# Verifica el resultado final
STATUS=$(aws acm describe-certificate \
  --certificate-arn "$CERT_ARN" \
  --region "$REGION" \
  --query "Certificate.Status" \
  --output text)

echo -ne "\r"

if [[ "$STATUS" == "ISSUED" ]]; then
    echo -e "${GREEN}✅ El certificado ha sido emitido exitosamente.${RESET}"
elif [[ "$STATUS" == "FAILED" ]]; then
    echo -e "${RED}❌ La solicitud del certificado falló. Revisa el dominio o el CNAME.${RESET}"
    exit 1
else
    echo -e "${YELLOW}⚠️ El certificado aún no se ha emitido. Verifica el CNAME en tu DNS.${RESET}"
    exit 1
fi
