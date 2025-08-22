data "azurerm_private_dns_zone" "private_dns_zone" {
  name                = local.private_dns_zone_name
  resource_group_name = var.resource_group_name
}

# List all VNet links for the private DNS zone
data "azapi_resource_list" "dns_zone_links" {
  count = local.is_private ? 1 : 0
  
  type                   = "Microsoft.Network/privateDnsZones/virtualNetworkLinks@2020-06-01"
  parent_id              = data.azurerm_private_dns_zone.private_dns_zone.id
  response_export_values = ["*"]
}

