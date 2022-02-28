terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "2.66.0"
    }
    azuread = {
      source  = "hashicorp/azuread"
      version = "~>0.7"
    }


  }

  required_version = ">= 0.14"
}