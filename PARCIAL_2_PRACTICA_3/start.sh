#!/usr/bin/env bash
# =============================================================================
#  start.sh — Levanta las 4 nubes, espera a que respondan y deja todo listo
#             para Terraform (certificado de Azure + llave de OCI).
# =============================================================================
set -euo pipefail
cd "$(dirname "$0")"

mkdir -p data/{aws,azure,gcp,oci} keys

echo ">> Descargando imágenes y levantando contenedores..."
docker compose pull -q
docker compose up -d

wait_for() {   # nombre url
  local name=$1 url=$2 tries=60
  printf "   %-6s " "$name"
  until code=$(curl -s -o /dev/null -w '%{http_code}' "$url") && [[ "$code" != "000" ]]; do
    ((tries--)) || { echo "✗ no respondió ($url)"; docker compose logs --tail 30; exit 1; }
    printf "."; sleep 2
  done
  echo " ✓ ($url → HTTP $code)"
}

echo ">> Esperando a que respondan los emuladores..."
wait_for AWS   http://127.0.0.1:4566/_localstack/health
wait_for Azure http://127.0.0.1:4577/_floci/tls-cert
wait_for GCP   http://127.0.0.1:4588/health
wait_for OCI   http://127.0.0.1:4599/_floci-oci/health

# -----------------------------------------------------------------------------
# Azure: confiar en el certificado autofirmado (azurerm lo exige)
# -----------------------------------------------------------------------------
echo ">> Confiando el certificado TLS de floci-az en el sistema..."
curl -sf http://127.0.0.1:4577/_floci/tls-cert -o keys/floci-az.crt
if ! grep -q "BEGIN CERTIFICATE" keys/floci-az.crt; then
  echo "   ✗ No llegó un certificado. ¿Está FLOCI_AZ_TLS_ENABLED=true?"; cat keys/floci-az.crt; exit 1
fi
if ! sudo cmp -s keys/floci-az.crt /etc/pki/ca-trust/source/anchors/floci-az.crt 2>/dev/null; then
  sudo cp keys/floci-az.crt /etc/pki/ca-trust/source/anchors/floci-az.crt
  sudo update-ca-trust extract
  echo "   ✓ Certificado instalado en /etc/pki/ca-trust/source/anchors/"
else
  echo "   ✓ Certificado ya estaba instalado"
fi

# -----------------------------------------------------------------------------
# OCI: llave RSA desechable (floci-oci lee la firma pero nunca la verifica)
# -----------------------------------------------------------------------------
if [[ ! -f keys/oci_floci_key.pem ]]; then
  echo ">> Generando llave desechable para OCI..."
  openssl genrsa -out keys/oci_floci_key.pem 2048 2>/dev/null
  chmod 600 keys/oci_floci_key.pem
fi

echo
docker compose ps --format 'table {{.Name}}\t{{.Status}}\t{{.Ports}}'
cat <<'EOF'

==========================================================================
 Laboratorio arriba.
   AWS    http://127.0.0.1:4566     consola: http://127.0.0.1:4566/_floci/ui
   Azure  https://127.0.0.1:4577
   GCP    http://127.0.0.1:4588
   OCI    http://127.0.0.1:4599

 Variables para CLIs:   source ./floci-env.sh
 Probar Terraform:      cd terraform/aws && terraform init && terraform apply
==========================================================================
EOF
