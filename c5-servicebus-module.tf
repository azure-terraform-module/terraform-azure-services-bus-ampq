# Create private DNS zone if not provided - Private endpoint
resource "azurerm_private_dns_zone" "private_dns_servicebus" {
  count               = local.is_private && length(var.servicebus_private_dns_zone_ids) == 0 ? 1 : 0
  name                = "privatelink.servicebus.cache.windows.net"
  resource_group_name = var.resource_group_name
  tags                = var.tags
}

# Create private DNS zone link - Private endpoint
resource "azurerm_private_dns_zone_virtual_network_link" "servicebus_private_dns_zone_link" {
  for_each = (
    local.is_private && length(local.private_dns_zone_ids) == 0
    ? toset(var.vnet_ids)
    : toset([])
  )

  name                  = "${var.namespace}-dns-link-${basename(each.key)}"
  private_dns_zone_name = azurerm_private_dns_zone.private_dns_servicebus[0].name
  resource_group_name   = azurerm_private_dns_zone.private_dns_servicebus[0].resource_group_name
  virtual_network_id    = each.value
  tags                  = var.tags

  depends_on = [
    azurerm_private_dns_zone.private_dns_servicebus
  ]
}

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

  dynamic "private_dns_zone_group" {
    for_each = true ? [1] : []
    content {
      name                 = "default"
      private_dns_zone_ids = local.private_dns_zone_ids
    }
  }
  tags = var.tags
  depends_on = [
    azurerm_private_dns_zone.private_dns_servicebus,
    azurerm_private_dns_zone_virtual_network_link.servicebus_private_dns_zone_link
  ]
}

# Event Hub Namespace
resource "azurerm_servicebus_namespace" "servicebus_namespace" {
  name                          = var.namespace
  location                      = var.location
  resource_group_name           = var.resource_group_name
  sku                           = var.sku
  capacity                      = var.capacity
  tags                          = var.tags
  public_network_access_enabled = local.public_network_access
  premium_messaging_partitions  = var.premium_messaging_partitions

  dynamic "network_rule_set" {
    for_each = local.network_rulesets
    content {
      default_action                = network_rule_set.value.default_action
      public_network_access_enabled = network_rule_set.value.public_network_access_enabled
      ip_rules                      = network_rule_set.value.ip_rule
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
    type = "SystemAssigned"
  }
}

# Event Hub Queue
resource "azurerm_servicebus_queue" "servicebus_queue" {
  for_each     = toset(var.queues)
  name         = each.key
  namespace_id = azurerm_servicebus_namespace.servicebus_namespace.id
}

# Event Hub Topic 
resource "azurerm_servicebus_topic" "servicebus_topic" {
  for_each     = toset(var.topics)
  name         = each.key
  namespace_id = azurerm_servicebus_namespace.servicebus_namespace.id
}
