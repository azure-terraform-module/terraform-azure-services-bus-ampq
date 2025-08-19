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

variable "servicebus_private_dns_zone_ids" {
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
    condition     = var.sku == "Premium" ? var.capacity >= 1 : true
    error_message = "Only Premium SKU can have capacity greater than 1."
  }
}

variable "premium_messaging_partitions" {
  description = "Number of messaging partitions for Premium SKU. If null, falls back to capacity."
  type        = number
  default     = null
  validation {
    condition     = var.sku == "Premium" ? var.premium_messaging_partitions >= 1 : true
    error_message = "Only Premium SKU can have premium_messaging_partitions greater than 1."
  }
}

variable "queues" {
  description = "List of queue objects to create. Each item: { name, partitioning_enabled, requires_duplicate_detection }. Flags default to true."
  type = list(object({
    name                         = string
    partitioning_enabled         = optional(bool)
    requires_duplicate_detection = optional(bool)
  }))
  default = []
}

variable "topics" {
  description = "List of topic objects to create. Each item: { name, partitioning_enabled, requires_duplicate_detection }. Flags default to true."
  type = list(object({
    name                         = string
    partitioning_enabled         = optional(bool)
    requires_duplicate_detection = optional(bool)
  }))
  default = []
}

variable "ip_rules" {
  description = "CIDR blocks to allow access to the Azure Cache - Only for service endpoints."
  type        = list(string)
  default     = []
}
