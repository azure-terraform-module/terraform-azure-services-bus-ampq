######################################
##              NETWORK             ##
######################################
variable "vnet_ids" {
  description = "The resource ID of the virtual network."
  type        = list(string)
  default     = []
}

variable "subnet_ids" {
  description = "The resource ID of the subnet for the private endpoint."
  type        = list(string)
  default     = []
}

variable "private_dns_zone_ids" {
  description = "The resource ID of the private DNS zone"
  type        = list(string)
  default     = []
}

variable "network_mode" {
  description = "Network mode for Service bus private, service, public."
  type        = string
  default     = "public"
  validation {
    condition = var.sku != "Premium" && contains(["private", "service"], var.network_mode) ? false : true
    error_message = "Network mode private and service are only supported for Premium SKU."
  }
  validation {
    condition     = contains(["public", "private", "service"], var.network_mode)
    error_message = "network_mode must be one of: public, private, service."
  }
}

######################################
##           SERVICE BUS            ##
######################################
variable "namespace" {
  description = "The name of the Service Bus namespace."
  type        = string
}

variable "sku" {
  description = "The SKU of the Service Bus namespace."
  type        = string
  default     = "Premium"
}

variable "capacity" {
  description = "The capacity of the Service Bus namespace."
  type        = number
  default     = null
  validation {
    condition     = var.capacity == null || contains([1, 2, 4, 8], var.capacity)
    error_message = "capacity must be one of: 1, 2, 4, 8."
  }

  validation {
    condition     = var.sku != "Premium" ? var.capacity == null : true
    error_message = "For Premium SKU, capacity is required (1, 2, 4, or 8). You can omit it to use the module’s default of 1."
  }
}

variable "premium_messaging_partitions" {
  description = "Number of messaging partitions for Premium SKU"
  type        = number
  default     = null
  validation {
    condition     = var.sku != "Premium" && var.premium_messaging_partitions != null ? false : true
    error_message = "Only Premium SKU can set messaging partitions."
  }
}

variable "queues" {
  description = "List of queue objects to create. Each item: { name, partitioning_enabled, requires_duplicate_detection }. Flags default to false."
  type = list(object({
    name                         = string
    partitioning_enabled         = optional(bool)
    requires_duplicate_detection = optional(bool)
  }))
  default = []
}

variable "topics" {
  description = "List of topic objects to create. Each item: { name, partitioning_enabled, requires_duplicate_detection }. Flags default to false."
  type = list(object({
    name                         = string
    partitioning_enabled         = optional(bool)
    requires_duplicate_detection = optional(bool)
  }))
  default = []
}

######################################
##        SECURITY & ENCRYPTION     ##
######################################
variable "local_auth_enabled" {
  description = "Whether to enable local (SAS) authentication on the Service Bus namespace. Set to false to enforce Entra ID only."
  type        = bool
  default     = false
}

variable "customer_managed_key" {
  description = "Customer-managed key configuration for encrypting the Service Bus namespace. Premium SKU only. Requires a user-assigned identity with access to the key."
  type = object({
    key_vault_key_id          = string
    user_assigned_identity_id = string
  })
  default = null
  validation {
    condition     = var.customer_managed_key == null || var.sku == "Premium"
    error_message = "customer_managed_key requires Premium SKU."
  }
}

