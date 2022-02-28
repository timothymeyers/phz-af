resource "random_pet" "prefix" {}

terraform {
  backend "azurerm" {
    resource_group_name  = "phopstfstates"
    storage_account_name = "phopstf"
    container_name       = "tfstatedevops"
    key                  = "tfstatedevops.tfstate"
  }
}

provider "azurerm" {
  features {}
}

provider "azuread" {
  features {}
}

### Resource Group

resource "azurerm_resource_group" "default" {
  name     = "${random_pet.prefix.id}-rg"
  location = "East US"

  tags = {
    environment = "Demo"
  }
}

### Azure Log Analytics Workspace

resource "azurerm_log_analytics_workspace" "default" {
  name                = "${random_pet.prefix.id}-law"
  resource_group_name = azurerm_resource_group.default.name
  location            = azurerm_resource_group.default.location
  sku                 = "PerGB2018"
}

resource "azurerm_log_analytics_solution" "default" {
  solution_name         = "Containers"
  workspace_resource_id = azurerm_log_analytics_workspace.default.id
  workspace_name        = azurerm_log_analytics_workspace.default.name
  location              = azurerm_resource_group.default.location
  resource_group_name   = azurerm_resource_group.default.name

  plan {
    publisher = "Microsoft"
    product   = "OMSGallery/Containers"
  }
}

### Azure Container Registry

resource "azurerm_container_registry" "default" {
  name                     = replace("${random_pet.prefix.id}-acr","-","")
  location                 = azurerm_resource_group.default.location
  resource_group_name      = azurerm_resource_group.default.name
  sku                      = "Basic"
  admin_enabled            = false
}

### Azure Kubernetes Service

resource "azurerm_kubernetes_cluster" "default" {
  name                = "${random_pet.prefix.id}-aks"
  location            = azurerm_resource_group.default.location
  resource_group_name = azurerm_resource_group.default.name
  dns_prefix          = "${random_pet.prefix.id}-k8s"

  default_node_pool {
    name            = "default"
    node_count      = 2
    vm_size         = "Standard_D2_v2"
    os_disk_size_gb = 30
  }

  identity {
    type = "SystemAssigned"
  }

#  service_principal {
#    client_id     = var.appId
#    client_secret = var.password
#  }

  role_based_access_control {
    enabled = true
  }

  tags = {
    environment = "Demo"
  }

  addon_profile {

    kube_dashboard {
      enabled = true
    }

    oms_agent {
      enabled = true
      log_analytics_workspace_id = "${azurerm_log_analytics_workspace.default.id}"
    }

  }

}



data "azuread_service_principal" "aks_principal" {
  application_id = var.appId
}

resource "azurerm_role_assignment" "acrpull_role" {
  scope                            = azurerm_container_registry.default.id
  role_definition_name             = "AcrPull"
  principal_id                     = data.azuread_service_principal.aks_principal.id
  skip_service_principal_aad_check = true
}