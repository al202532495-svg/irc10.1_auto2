# =============================================================================
#  Demo GCP sobre floci-gcp (:4588)
#  Antes:  export GOOGLE_OAUTH_ACCESS_TOKEN=floci   (o: source ../../floci-env.sh)
#  Muestra: Cloud Storage, cuenta de servicio (IAM), Secret Manager, Cloud KMS
#
#  Nota: Pub/Sub, Firestore y Datastore solo hablan gRPC en floci-gcp, así que
#  Terraform (que usa REST) no los puede crear todavía. Muéstralos con gcloud
#  o con un SDK.
# =============================================================================
terraform {
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 7.0"
    }
  }
}

variable "endpoint" {
  type    = string
  default = "http://localhost:4588"
}

variable "project" {
  type    = string
  default = "floci-local"
}

variable "region" {
  type    = string
  default = "us-central1"
}

provider "google" {
  project               = var.project
  region                = var.region
  user_project_override = false

  # Cada API se redirige al emulador (rutas tomadas de la suite oficial de floci-gcp)
  storage_custom_endpoint          = "${var.endpoint}/storage/v1/"
  iam_custom_endpoint              = "${var.endpoint}/"
  iam_beta_custom_endpoint         = "${var.endpoint}/v1/"
  secret_manager_custom_endpoint   = "${var.endpoint}/v1/"
  kms_custom_endpoint              = "${var.endpoint}/v1/"
  cloud_run_v2_custom_endpoint     = "${var.endpoint}/v2/"
  sql_custom_endpoint              = "${var.endpoint}/sql/v1beta4/"
  service_usage_custom_endpoint    = "${var.endpoint}/v1/"
  resource_manager_custom_endpoint = "${var.endpoint}/v1/"
}

# ── Almacenamiento ───────────────────────────────────────────────────────────
resource "google_storage_bucket" "app" {
  name                        = "demo-floci-gcp-bucket"
  location                    = "US"
  force_destroy               = true
  uniform_bucket_level_access = false
  labels                      = { proyecto = "demo-floci", nube = "gcp" }
}

resource "google_storage_bucket_object" "hola" {
  bucket       = google_storage_bucket.app.name
  name         = "hola.txt"
  content      = "Hola desde Terraform + Floci (GCP)"
  content_type = "text/plain"
}

# ── Identidad ────────────────────────────────────────────────────────────────
resource "google_service_account" "app" {
  account_id   = "demo-app-sa"
  display_name = "Cuenta de servicio de la demo"
}

# ── Secretos ─────────────────────────────────────────────────────────────────
resource "google_secret_manager_secret" "db" {
  secret_id = "demo-db-password"
  project   = var.project
  replication {
    auto {}
  }
}

resource "google_secret_manager_secret_version" "db" {
  secret      = google_secret_manager_secret.db.id
  secret_data = "contraseña-de-laboratorio"
}

# ── Cifrado ──────────────────────────────────────────────────────────────────
resource "google_kms_key_ring" "demo" {
  name     = "demo-keyring"
  location = var.region
  project  = var.project
}

resource "google_kms_crypto_key" "demo" {
  name     = "demo-key"
  key_ring = google_kms_key_ring.demo.id
  purpose  = "ENCRYPT_DECRYPT"
}

# ── (Opcional) Cloud SQL: levanta un Postgres real en Docker ─────────────────
# Descomenta para mostrar una base de datos administrada (consume ~300 MB RAM).
# resource "google_sql_database_instance" "pg" {
#   name                = "demo-postgres"
#   region              = var.region
#   database_version    = "POSTGRES_16"
#   deletion_protection = false
#   settings { tier = "db-custom-1-3840" }
# }

# ── Salidas ──────────────────────────────────────────────────────────────────
output "bucket"          { value = google_storage_bucket.app.name }
output "service_account" { value = google_service_account.app.email }
output "secreto"         { value = google_secret_manager_secret.db.name }
output "kms_key"         { value = google_kms_crypto_key.demo.id }
