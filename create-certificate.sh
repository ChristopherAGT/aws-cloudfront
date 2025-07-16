#!/bin/bash

# Solicita el dominio al usuario
read -p "Ingresa el dominio raíz (ej: abysscore.xyz): " DOMAIN

# Verifica si se ingresó algo
if [[ -z "$DOMAIN" ]]; then
    echo "❌ Error: No ingresaste un dominio."
    exit 1
fi

# Construye el dominio con wildcard
WILDCARD="*.$DOMAIN"

# Región para el certificado (us-east-1 es común, especialmente para CloudFront)
REGION="us-east-1"

# Solicita el certificado
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
echo "⏳ Esperando 10 segundos antes de recuperar la información de validación..."
sleep 10

# Obtener los datos de validación DNS
VALIDATION=$(aws acm describe-certificate \
  --certificate-arn "$CERT_ARN" \
  --region "$REGION" \
  --query "Certificate.DomainValidationOptions[0].ResourceRecord" \
  --output text)

# Separar los valores
CNAME_NAME=$(echo "$VALIDATION" | awk '{print $1}')
CNAME_TYPE=$(echo "$VALIDATION" | awk '{print $2}')
CNAME_VALUE=$(echo "$VALIDATION" | awk '{print $3}')

# Mostrar en formato para Cloudflare
echo ""
echo "🧾 Añade el siguiente registro en Cloudflare para validar tu certificado:"
echo "======================================================================="
printf "%-20s | %-60s\n" "Nombre (CNAME)" "Valor (CNAME)"
echo "---------------------+--------------------------------------------------------------"
printf "%-20s | %-60s\n" "$CNAME_NAME" "$CNAME_VALUE"
echo "======================================================================="
echo ""
echo "✅ Una vez añadido, ACM validará automáticamente tu dominio."
