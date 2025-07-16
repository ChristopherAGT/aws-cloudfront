#!/bin/bash

# Solicita el dominio al usuario
read -p "Ingresa el dominio raíz (ej: abysscore.xyz): " DOMAIN

if [[ -z "$DOMAIN" ]]; then
    echo "❌ Error: No ingresaste un dominio."
    exit 1
fi

WILDCARD="*.$DOMAIN"
REGION="us-east-1"

echo "🚀 Solicitando certificado para $WILDCARD..."

CERT_ARN=$(aws acm request-certificate \
  --domain-name "$WILDCARD" \
  --validation-method DNS \
  --region "$REGION" \
  --output text \
  --query CertificateArn)

if [[ -z "$CERT_ARN" ]]; then
    echo "❌ No se pudo solicitar el certificado."
    exit 1
fi

echo "✅ Certificado solicitado con ARN:"
echo "$CERT_ARN"
echo "⏳ Esperando unos segundos antes de mostrar los datos de validación..."
sleep 10

VALIDATION=$(aws acm describe-certificate \
  --certificate-arn "$CERT_ARN" \
  --region "$REGION" \
  --query "Certificate.DomainValidationOptions[0].ResourceRecord" \
  --output text)

CNAME_NAME=$(echo "$VALIDATION" | awk '{print $1}')
CNAME_VALUE=$(echo "$VALIDATION" | awk '{print $3}')

echo ""
echo "🧾 Añade el siguiente CNAME en Cloudflare:"
echo "======================================================================="
printf "%-20s | %-60s\n" "Nombre (CNAME)" "Valor (CNAME)"
echo "---------------------+--------------------------------------------------------------"
printf "%-20s | %-60s\n" "$CNAME_NAME" "$CNAME_VALUE"
echo "======================================================================="
echo ""
echo "⏳ Esperando validación de dominio (esto puede tardar varios minutos)..."

# Esperar a que el certificado esté en estado ISSUED
for i in {1..30}; do
    STATUS=$(aws acm describe-certificate \
      --certificate-arn "$CERT_ARN" \
      --region "$REGION" \
      --query "Certificate.Status" \
      --output text)

    echo "🔄 Estado actual del certificado: $STATUS"

    if [[ "$STATUS" == "ISSUED" ]]; then
        echo "✅ El certificado ha sido emitido exitosamente."
        break
    elif [[ "$STATUS" == "FAILED" ]]; then
        echo "❌ La solicitud del certificado falló. Revisa el dominio o el CNAME."
        exit 1
    fi

    sleep 30  # Espera 30 segundos antes de verificar otra vez
done

if [[ "$STATUS" != "ISSUED" ]]; then
    echo "⚠️ El certificado aún no se ha emitido después de varios intentos. Verifica el CNAME en Cloudflare."
    exit 1
fi
