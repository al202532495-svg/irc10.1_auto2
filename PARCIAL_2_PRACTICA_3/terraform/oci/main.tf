# =============================================================================
#  Demo Oracle Cloud (OCI) sobre floci-oci (:4599)
#  Antes:  source ../../floci-env.sh   (exporta TF_VAR_CLIENT_HOST_OVERRIDES,
#          que es como el provider oracle/oci redirige cada cliente al emulador)
#  Muestra: compartimento (IAM) y Object Storage
# =============================================================================
terraform {
  required_providers {
    oci = {
      source = "oracle/oci"
    }
  }
}

locals {
  tenancy   = "ocid1.tenancy.oc1..flocilocaltenancy0000000000000000000000000000000000000000"
  namespace = "floci-local"
}

provider "oci" {
  tenancy_ocid     = local.tenancy
  user_ocid        = "ocid1.user.oc1..anyuser"
  fingerprint      = "aa:bb:cc:dd:ee:ff:00:11:22:33:44:55:66:77:88:99"
  private_key_path = "${path.module}/../../keys/oci_floci_key.pem"   # la genera start.sh
  region           = "us-ashburn-1"
}

# ── Identidad ────────────────────────────────────────────────────────────────
resource "oci_identity_compartment" "demo" {
  compartment_id = local.tenancy
  name           = "demo-floci"
  description    = "Compartimento de la demo"
  enable_delete  = true
}

# ── Almacenamiento ───────────────────────────────────────────────────────────
resource "oci_objectstorage_bucket" "app" {
  compartment_id = oci_identity_compartment.demo.id
  namespace      = local.namespace
  name           = "demo-floci-oci-bucket"
  access_type    = "NoPublicAccess"
}

resource "oci_objectstorage_object" "hola" {
  namespace    = local.namespace
  bucket       = oci_objectstorage_bucket.app.name
  object       = "hola.txt"
  content      = "Hola desde Terraform + Floci (OCI)"
  content_type = "text/plain"
}

# ── Salidas ──────────────────────────────────────────────────────────────────
output "compartment" { value = oci_identity_compartment.demo.id }
output "bucket"      { value = oci_objectstorage_bucket.app.name }
