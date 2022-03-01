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

provider "azuread" {}


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

resource "azurerm_kubernetes_cluster" "prod" {
  name                = "${random_pet.prefix.id}-aks"
  location            = azurerm_resource_group.default.location
  resource_group_name = azurerm_resource_group.default.name
  dns_prefix          = "${random_pet.prefix.id}-k8s"

  default_node_pool {
    name            = "system"
    node_count      = 3
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
    oms_agent {
      enabled = true
      log_analytics_workspace_id = "${azurerm_log_analytics_workspace.default.id}"
    }

  }

}

resource "azurerm_kubernetes_cluster_node_pool" "horizon" {
  name                  = "horizon"
  kubernetes_cluster_id = azurerm_kubernetes_cluster.prod.id
  vm_size               = "Standard_DS2_v2"
  node_count            = 9
}

### Staging cluster

resource "azurerm_kubernetes_cluster" "staging" {
  name                = "${random_pet.prefix.id}-aks"
  location            = azurerm_resource_group.default.location
  resource_group_name = azurerm_resource_group.default.name
  dns_prefix          = "${random_pet.prefix.id}-k8s"

  default_node_pool {
    name            = "system"
    node_count      = 3
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
    oms_agent {
      enabled = true
      log_analytics_workspace_id = "${azurerm_log_analytics_workspace.default.id}"
    }

  }

}

resource "azurerm_kubernetes_cluster_node_pool" "horizon-staging" {
  name                  = "horizon"
  kubernetes_cluster_id = azurerm_kubernetes_cluster.staging.id
  vm_size               = "Standard_DS2_v2"
  node_count            = 3
}

### Assign AcrPull to AKS for the ACR we created

# data "azuread_service_principal" "aks_principal" {
#   application_id = var.appId
# }

# data "azurerm_kubernetes_cluster" "aks_principal" {
#   
# }

resource "azurerm_role_assignment" "acrpull_role_prod" {
  scope                            = azurerm_container_registry.default.id
  role_definition_name             = "AcrPull"
#   principal_id                     = data.azuread_service_principal.aks_principal.id
  principal_id                     = azurerm_kubernetes_cluster.prod.identity.0.principal_id
  skip_service_principal_aad_check = true
}

resource "azurerm_role_assignment" "acrpull_role_staging" {
  scope                            = azurerm_container_registry.default.id
  role_definition_name             = "AcrPull"
#   principal_id                     = data.azuread_service_principal.aks_principal.id
  principal_id                     = azurerm_kubernetes_cluster.staging.identity.0.principal_id
  skip_service_principal_aad_check = true
}