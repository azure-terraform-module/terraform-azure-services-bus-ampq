variable "resource_group_name" {
  description = "The name of the resource group where the resources will be created."
  type        = string
}

variable "location" {
  description = "The Azure location where the resources will be created."
  type        = string
}

variable "tags" {
  description = "Tags to assign to the resource."
  type        = map(string)
  default     = {}
}