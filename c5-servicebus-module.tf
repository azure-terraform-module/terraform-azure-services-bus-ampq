# Create private DNS zone if not provided - Private endpoint
resource "azurerm_private_dns_zone" "private_dns_servicebus" {
  count               = local.create_private_dns_zone ? 1 : 0
  name                = local.private_dns_zone_name
  resource_group_name = var.resource_group_name
  tags                = var.tags
}

# Create private DNS zone links for VNets that don't already have them
resource "azurerm_private_dns_zone_virtual_network_link" "private_dns_servicebus_link" {
  count = local.is_private ? length(local.vnets_needing_links) : 0
  
  name                  = "${var.namespace}-tf-managed-vnet-link-${count.index}"
  resource_group_name   = try(data.azurerm_private_dns_zone.private_dns_zone.resource_group_name, var.resource_group_name)
  private_dns_zone_name = try(data.azurerm_private_dns_zone.private_dns_zone.name, local.private_dns_zone_name)
  virtual_network_id    = local.vnets_needing_links[count.index]
  registration_enabled  = false
  
  depends_on = [azurerm_private_dns_zone.private_dns_servicebus]
}

# Create private endpoint - Private endpoint
resource "azurerm_private_endpoint" "servicebus_private_endpoint" {
  count = local.is_private ? length(var.subnet_ids) : 0
  name                = "${var.namespace}-private-endpoint-${basename(var.subnet_ids[count.index])}"
  location            = var.location
  resource_group_name = var.resource_group_name
  subnet_id           = var.subnet_ids[count.index]

  private_service_connection {
    name                           = "${var.namespace}-private-connection-${basename(var.subnet_ids[count.index])}"
    private_connection_resource_id = azurerm_servicebus_namespace.servicebus_namespace.id
    is_manual_connection           = false
    subresource_names              = ["namespace"]
  }

  dynamic "private_dns_zone_group" {
    for_each = try(
      try(data.azurerm_private_dns_zone.private_dns_zone.id, null) != null ||
      length(azurerm_private_dns_zone.private_dns_servicebus) > 0
    ) ? [1] : []
    content {
      name                 = "default"
      private_dns_zone_ids = [
        try(
          data.azurerm_private_dns_zone.private_dns_zone.id,
          azurerm_private_dns_zone.private_dns_servicebus[0].id
        )
      ]
    }
  }

  tags = var.tags
}

# Service Bus Namespace
resource "azurerm_servicebus_namespace" "servicebus_namespace" {
  name                          = var.namespace
  location                      = var.location
  resource_group_name           = var.resource_group_name
  sku                           = var.sku
  capacity                      = var.sku == "Premium" ? coalesce(var.capacity, 1) : null
  tags                          = var.tags
  public_network_access_enabled = local.public_network_access
  premium_messaging_partitions  = var.sku == "Premium" ? var.premium_messaging_partitions : null

  minimum_tls_version        = "1.2"
  local_auth_enabled         = var.local_auth_enabled

  dynamic "network_rule_set" {
    for_each = var.sku == "Premium" ? [local.network_rulesets] : []
    content {
      default_action                = network_rule_set.value.default_action
      public_network_access_enabled = network_rule_set.value.public_network_access_enabled
      dynamic "network_rules" {
        for_each = var.subnet_ids
        content {
          subnet_id                            = network_rules.value
          ignore_missing_vnet_service_endpoint = false
        }
      }
    }
  }


  identity {
    type         = var.customer_managed_key == null ? "SystemAssigned" : "UserAssigned"
    identity_ids = var.customer_managed_key == null || try(var.customer_managed_key.user_assigned_identity_id, null) == null ? null : [var.customer_managed_key.user_assigned_identity_id]
  }

  lifecycle {
    precondition {
      condition     = var.customer_managed_key == null || try(var.customer_managed_key.user_assigned_identity_id, null) != null
      error_message = "customer_managed_key requires user_assigned_identity_id for Key Vault access."
    }
  }

  dynamic "customer_managed_key" {
    for_each = var.customer_managed_key == null ? [] : [var.customer_managed_key]
    content {
      infrastructure_encryption_enabled = true
      key_vault_key_id = customer_managed_key.value.key_vault_key_id
      identity_id      = customer_managed_key.value.user_assigned_identity_id
    }
  }
}

# Create Service Bus queues and topics.
# Defaults: 
# - partitioning_enabled = false
# - requires_duplicate_detection = false
# Premium SKU: 
# - partitioning_enabled must stay false (error if set true) because in Premium SKU, partitioning are defind in the namespace level.
# - requires_duplicate_detection can be set other values.
# Standard/Basic SKU: 
# - Can be set other values.

# Service Bus Queue
resource "azurerm_servicebus_queue" "servicebus_queue" {
  for_each     = { for q in var.queues : q.name => q }
  name         = each.value.name
  namespace_id = azurerm_servicebus_namespace.servicebus_namespace.id
  partitioning_enabled          = lookup(each.value, "partitioning_enabled", false)
  requires_duplicate_detection  = lookup(each.value, "requires_duplicate_detection", false)

  lifecycle {
    precondition {
      condition     = !(var.sku == "Premium" && lookup(each.value, "partitioning_enabled", false) == true)
      error_message = "partitioning_enabled is ignored for Premium SKU; remove this setting or switch to Standard/Basic."
    }
  }
}

# Service Bus Topic 
resource "azurerm_servicebus_topic" "servicebus_topic" {
  for_each     = { for t in var.topics : t.name => t }
  name         = each.value.name
  namespace_id = azurerm_servicebus_namespace.servicebus_namespace.id
  partitioning_enabled          = lookup(each.value, "partitioning_enabled", false)
  requires_duplicate_detection  = lookup(each.value, "requires_duplicate_detection", false)

  lifecycle {
    precondition {
      condition     = !(var.sku == "Premium" && lookup(each.value, "partitioning_enabled", false) == true)
      error_message = "partitioning_enabled is ignored for Premium SKU; remove this setting or switch to Standard/Basic."
    }
  }
}
