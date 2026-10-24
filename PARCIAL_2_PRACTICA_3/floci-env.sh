# =============================================================================
#  floci-env.sh — Variables para que las CLIs y Terraform apunten a Floci.
#  Uso:   source ./floci-env.sh
# =============================================================================
_FLOCI_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# ---------------- AWS ----------------
export AWS_ENDPOINT_URL=http://localhost:4566
export AWS_ACCESS_KEY_ID=test
export AWS_SECRET_ACCESS_KEY=test
export AWS_DEFAULT_REGION=us-east-1

# ---------------- Azure ----------------
export AZURE_STORAGE_CONNECTION_STRING="DefaultEndpointsProtocol=http;AccountName=devstoreaccount1;AccountKey=Eby8vdM02xNOcqFlqUwJPLlmEtlCDXJ1OUzFT50uSRZ6IFsuFq2UVErCz4I6tq/K1SZFPTOtr/KBHBeksoGMGw==;BlobEndpoint=http://localhost:4577/devstoreaccount1;QueueEndpoint=http://localhost:4577/devstoreaccount1;TableEndpoint=http://localhost:4577/devstoreaccount1;"

# ---------------- GCP ----------------
export GOOGLE_CLOUD_PROJECT=floci-local
export GOOGLE_OAUTH_ACCESS_TOKEN=floci          # token falso; Terraform lo usa
export STORAGE_EMULATOR_HOST=http://localhost:4588
export PUBSUB_EMULATOR_HOST=localhost:4588
export FIRESTORE_EMULATOR_HOST=localhost:4588
export DATASTORE_EMULATOR_HOST=localhost:4588
export SECRET_MANAGER_EMULATOR_HOST=localhost:4588
export CLOUDSDK_CORE_PROJECT=floci-local
export CLOUDSDK_AUTH_ACCESS_TOKEN=floci
export CLOUDSDK_API_ENDPOINT_OVERRIDES_STORAGE=http://localhost:4588/
export CLOUDSDK_API_ENDPOINT_OVERRIDES_PUBSUB=http://localhost:4588/
export CLOUDSDK_API_ENDPOINT_OVERRIDES_SECRETMANAGER=http://localhost:4588/

# ---------------- OCI ----------------
export OCI_TENANCY=ocid1.tenancy.oc1..flocilocaltenancy0000000000000000000000000000000000000000
# El provider oracle/oci lee esta variable para redirigir cada cliente al emulador
export TF_VAR_CLIENT_HOST_OVERRIDES="oci_identity.IdentityClient=http://localhost:4599;oci_object_storage.ObjectStorageClient=http://localhost:4599"
alias ocil='oci --endpoint http://localhost:4599 --config-file "'"$_FLOCI_DIR"'/keys/oci_config" --profile FLOCI'

# Config de la CLI de OCI apuntando a la llave desechable
if [[ -f "$_FLOCI_DIR/keys/oci_floci_key.pem" && ! -f "$_FLOCI_DIR/keys/oci_config" ]]; then
  cat > "$_FLOCI_DIR/keys/oci_config" <<EOF
[FLOCI]
user=ocid1.user.oc1..flocilocaluser0000000000000000000000000000000000000000000000
fingerprint=aa:bb:cc:dd:ee:ff:00:11:22:33:44:55:66:77:88:99
tenancy=$OCI_TENANCY
region=us-ashburn-1
key_file=$_FLOCI_DIR/keys/oci_floci_key.pem
EOF
  chmod 600 "$_FLOCI_DIR/keys/oci_config"
fi

echo "✓ Variables de Floci cargadas (AWS, Azure, GCP, OCI). Alias: ocil"
