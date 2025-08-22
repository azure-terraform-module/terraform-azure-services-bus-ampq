terraform {
  required_version = ">= 1.5, < 2.0"
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 4.25.0"
    }
    azapi = {
      source  = "azure/azapi"
      version = ">= 1.0.0"
    }
  }
 }


