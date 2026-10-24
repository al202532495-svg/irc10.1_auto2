# =============================================================================
#  Demo Azure sobre floci-az (:4577)
#  Requisitos: FLOCI_AZ_TLS_ENABLED=true y el certificado confiado
#              (start.sh hace ambas cosas)
#  Muestra: resource group, VNet/subnets/NSG, Storage Account + contenedor,
#           Key Vault
# =============================================================================
terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 4.0"   # floci-az soporta 3.x y 4.x; la 5.x cambia argumentos obligatorios
    }
  }
}

provider "azurerm" {
  features {}
  resource_provider_registrations = "none"
  use_cli                         = false

  environment   = "stack"            # nube personalizada descrita por metadata_host
  metadata_host = "localhost:4577"   # floci-az sirve /metadata/endpoints por HTTPS

  subscription_id = "00000000-0000-0000-0000-000000000001"
  tenant_id       = "00000000-0000-0000-0000-000000000002"
  client_id       = "00000000-0000-0000-0000-000000000003"
  client_secret   = "fake-secret"    # no se valida
}

locals {
  location = "eastus"
  tags     = { proyecto = "demo-floci", nube = "azure" }
}

# ── Resource group ───────────────────────────────────────────────────────────
resource "azurerm_resource_group" "demo" {
  name     = "rg-demo-floci"
  location = local.location
  tags     = local.tags
}

# ── Red ──────────────────────────────────────────────────────────────────────
resource "azurerm_virtual_network" "demo" {
  name                = "vnet-demo"
  address_space       = ["10.20.0.0/16"]
  location            = azurerm_resource_group.demo.location
  resource_group_name = azurerm_resource_group.demo.name
  tags                = local.tags
}

resource "azurerm_subnet" "app" {
  name                 = "snet-app"
  resource_group_name  = azurerm_resource_group.demo.name
  virtual_network_name = azurerm_virtual_network.demo.name
  address_prefixes     = ["10.20.1.0/24"]
}

resource "azurerm_network_security_group" "app" {
  name                = "nsg-app"
  location            = azurerm_resource_group.demo.location
  resource_group_name = azurerm_resource_group.demo.name

  security_rule {
    name                       = "allow-https"
    priority                   = 100
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "443"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }
}

# ── Almacenamiento ───────────────────────────────────────────────────────────
resource "azurerm_storage_account" "demo" {
  name                     = "stdemofloci01"   # 3-24 caracteres, minúsculas y números
  resource_group_name      = azurerm_resource_group.demo.name
  location                 = azurerm_resource_group.demo.location
  account_tier             = "Standard"
  account_replication_type = "LRS"
  tags                     = local.tags
}

# ── Secretos ─────────────────────────────────────────────────────────────────
resource "azurerm_key_vault" "demo" {
  name                = "kv-demo-floci"
  location            = azurerm_resource_group.demo.location
  resource_group_name = azurerm_resource_group.demo.name
  tenant_id           = "00000000-0000-0000-0000-000000000002"
  sku_name            = "standard"
}

# ── Salidas ──────────────────────────────────────────────────────────────────
output "resource_group" { value = azurerm_resource_group.demo.name }
output "vnet_id"        { value = azurerm_virtual_network.demo.id }
output "storage"        { value = azurerm_storage_account.demo.name }
output "key_vault"      { value = azurerm_key_vault.demo.name }
