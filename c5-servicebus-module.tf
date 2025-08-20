# Create private DNS zone if not provided - Private endpoint
resource "azurerm_private_dns_zone" "private_dns_servicebus" {
  count               = local.create_private_dns_zone ? 1 : 0
  name                = "privatelink.servicebus.windows.net"
  resource_group_name = var.resource_group_name
  tags                = var.tags
}

# Case 1: User not providing a private DNS zone ID, create a new one and link it to VNets - Private endpoint
resource "azurerm_private_dns_zone_virtual_network_link" "servicebus_private_dns_zone_link" {
  for_each = local.create_private_dns_zone ? toset(var.vnet_ids) : toset([])

  name                  = "${var.namespace}-dns-link-${basename(each.key)}"
  private_dns_zone_name = azurerm_private_dns_zone.private_dns_servicebus[0].name
  resource_group_name   = azurerm_private_dns_zone.private_dns_servicebus[0].resource_group_name
  virtual_network_id    = each.value
  tags                  = var.tags

  depends_on = [
    azurerm_private_dns_zone.private_dns_servicebus
  ]
}
#####

# Case 2: User providing a private DNS zone ID, create a link to VNets - Private endpoint
resource "azurerm_private_dns_zone_virtual_network_link" "servicebus_private_dns_zone_user_link" {
  for_each = !local.create_private_dns_zone && local.user_dns_zone_id != null ? toset(var.vnet_ids) : toset([])

  name                  = "${var.namespace}-dns-link-${basename(each.key)}"
  private_dns_zone_name = local.user_dns_zone_name
  resource_group_name   = local.user_dns_zone_rg
  virtual_network_id    = each.value
  tags                  = var.tags
}

#####

# Create private endpoint - Private endpoint
resource "azurerm_private_endpoint" "servicebus_private_endpoint" {
  for_each = (local.is_private
    ? toset(var.subnet_ids)
    : toset([])
  )
  name                = "${var.namespace}-private-endpoint-${local.subnet_info[each.key].name}"
  location            = var.location
  resource_group_name = var.resource_group_name
  subnet_id           = each.key

  private_service_connection {
    name                           = "${var.namespace}-private-connection-${local.subnet_info[each.key].name}"
    private_connection_resource_id = azurerm_servicebus_namespace.servicebus_namespace.id
    is_manual_connection           = false
    subresource_names              = ["namespace"]
  }
  
  tags = var.tags
  depends_on = [
    azurerm_private_dns_zone.private_dns_servicebus,
    azurerm_private_dns_zone_virtual_network_link.servicebus_private_dns_zone_link
  ]
}

# Manual Private DNS A record aggregating all Private Endpoint IPs (module-created zone)
resource "azurerm_private_dns_a_record" "servicebus_private_dns_record" {
  count               = local.create_private_dns_zone && length(azurerm_private_endpoint.servicebus_private_endpoint) > 0 ? 1 : 0
  name                = var.namespace
  zone_name           = azurerm_private_dns_zone.private_dns_servicebus[0].name
  resource_group_name = azurerm_private_dns_zone.private_dns_servicebus[0].resource_group_name
  ttl                 = 300
  records             = sort(distinct(flatten([
    for pe in values(azurerm_private_endpoint.servicebus_private_endpoint) : try(flatten([
      for cfg in pe.custom_dns_configs : cfg.ip_addresses
    ]), [])
  ])))
  depends_on = [
    azurerm_private_endpoint.servicebus_private_endpoint
  ]
}

# Manual Private DNS A record aggregating all Private Endpoint IPs (user-provided zone)
resource "azurerm_private_dns_a_record" "servicebus_private_dns_record_user" {
  count               = !local.create_private_dns_zone && local.user_dns_zone_id != null && length(azurerm_private_endpoint.servicebus_private_endpoint) > 0 ? 1 : 0
  name                = var.namespace
  zone_name           = local.user_dns_zone_name
  resource_group_name = local.user_dns_zone_rg
  ttl                 = 300
  records             = sort(distinct(flatten([
    for pe in values(azurerm_private_endpoint.servicebus_private_endpoint) : try(flatten([
      for cfg in pe.custom_dns_configs : cfg.ip_addresses
    ]), [])
  ])))
  depends_on = [
    azurerm_private_endpoint.servicebus_private_endpoint
  ]
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
    for_each = var.sku == "Premium" ? local.network_rulesets : []
    content {
      default_action                = network_rule_set.value.default_action
      public_network_access_enabled = network_rule_set.value.public_network_access_enabled
      trusted_service_access_enabled = network_rule_set.value.trusted_service_access_enabled
      dynamic "network_rules" {
        for_each = local.is_service ? toset(var.subnet_ids) : toset([])
        content {
          subnet_id                            = network_rules.value
          ignore_missing_vnet_service_endpoint = true
        }
      }
    }
  }


  identity {
    type         = var.customer_managed_key == null ? "SystemAssigned" : "UserAssigned"
    identity_ids = var.customer_managed_key == null ? null : [var.customer_managed_key.user_assigned_identity_id]
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
