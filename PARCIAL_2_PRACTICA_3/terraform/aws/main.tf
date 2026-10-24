# =============================================================================
#  Demo AWS sobre Floci (:4566)
#  Muestra: red (VPC/subnets), almacenamiento (S3), mensajería (SQS),
#           base NoSQL (DynamoDB), identidad (IAM) y configuración (SSM)
# =============================================================================
terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
  }
}

variable "endpoint" {
  type    = string
  default = "http://localhost:4566"
}

provider "aws" {
  region     = "us-east-1"
  access_key = "test"
  secret_key = "test"

  skip_credentials_validation = true
  skip_metadata_api_check     = true
  skip_requesting_account_id  = true
  s3_use_path_style           = true

  # Hay que declarar el endpoint de CADA servicio que use la configuración
  endpoints {
    ec2      = var.endpoint
    s3       = var.endpoint
    sqs      = var.endpoint
    dynamodb = var.endpoint
    iam      = var.endpoint
    sts      = var.endpoint
    ssm      = var.endpoint
  }

  default_tags {
    tags = { Proyecto = "demo-floci", Nube = "aws" }
  }
}

# ── Red ──────────────────────────────────────────────────────────────────────
resource "aws_vpc" "main" {
  cidr_block           = "10.10.0.0/16"
  enable_dns_hostnames = true
  tags                 = { Name = "demo-vpc" }
}

resource "aws_subnet" "public" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = "10.10.1.0/24"
  availability_zone       = "us-east-1a"
  map_public_ip_on_launch = true
  tags                    = { Name = "demo-public-a" }
}

resource "aws_subnet" "private" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = "10.10.2.0/24"
  availability_zone = "us-east-1b"
  tags              = { Name = "demo-private-b" }
}

resource "aws_security_group" "web" {
  name   = "demo-web-sg"
  vpc_id = aws_vpc.main.id

  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# ── Almacenamiento ───────────────────────────────────────────────────────────
resource "aws_s3_bucket" "app" {
  bucket = "demo-floci-app-bucket"
}

resource "aws_s3_bucket_versioning" "app" {
  bucket = aws_s3_bucket.app.id
  versioning_configuration { status = "Enabled" }
}

resource "aws_s3_object" "hola" {
  bucket       = aws_s3_bucket.app.id
  key          = "hola.txt"
  content      = "Hola desde Terraform + Floci (AWS)"
  content_type = "text/plain"
}

# ── Mensajería ───────────────────────────────────────────────────────────────
resource "aws_sqs_queue" "dlq" {
  name = "demo-pedidos-dlq"
}

resource "aws_sqs_queue" "pedidos" {
  name                       = "demo-pedidos"
  visibility_timeout_seconds = 30
  redrive_policy = jsonencode({
    deadLetterTargetArn = aws_sqs_queue.dlq.arn
    maxReceiveCount     = 3
  })
}

# ── Base de datos NoSQL ──────────────────────────────────────────────────────
resource "aws_dynamodb_table" "clientes" {
  name         = "demo-clientes"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "id"

  attribute {
    name = "id"
    type = "S"
  }
}

# ── Identidad ────────────────────────────────────────────────────────────────
resource "aws_iam_role" "app" {
  name = "demo-app-role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "ec2.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy" "app_s3" {
  name = "demo-app-s3-read"
  role = aws_iam_role.app.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect   = "Allow"
      Action   = ["s3:GetObject", "s3:ListBucket"]
      Resource = [aws_s3_bucket.app.arn, "${aws_s3_bucket.app.arn}/*"]
    }]
  })
}

# ── Configuración ────────────────────────────────────────────────────────────
resource "aws_ssm_parameter" "entorno" {
  name  = "/demo/entorno"
  type  = "String"
  value = "laboratorio-floci"
}

# ── Salidas ──────────────────────────────────────────────────────────────────
output "vpc_id"        { value = aws_vpc.main.id }
output "bucket"        { value = aws_s3_bucket.app.bucket }
output "cola_pedidos"  { value = aws_sqs_queue.pedidos.url }
output "tabla_dynamo"  { value = aws_dynamodb_table.clientes.name }
output "rol_iam"       { value = aws_iam_role.app.arn }
