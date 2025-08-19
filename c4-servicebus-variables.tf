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
  default     = 1
}

variable "premium_messaging_partitions" {
  description = "Number of messaging partitions for Premium SKU. If null, falls back to capacity."
  type        = number
  default     = 1
}

variable "queues" {
  description = "List of queues to create in the Service Bus namespace."
  type        = list(string)
  default     = []
}

variable "topics" {
  description = "List of topics to create in the Service Bus namespace."
  type        = list(string)
  default     = []
}

variable "ip_rules" {
  description = "CIDR blocks to allow access to the Azure Cache - Only for service endpoints."
  type        = list(string)
  default     = []
}
