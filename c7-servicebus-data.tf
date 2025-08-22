# List all private DNS zones in the resource group (never fails)
data "azapi_resource_list" "all_private_dns_zones" {
  count = local.is_private ? 1 : 0
  
  type                   = "Microsoft.Network/privateDnsZones@2020-06-01"
  parent_id              = "/subscriptions/${var.subscription_id}/resourceGroups/${var.resource_group_name}"
  response_export_values = ["*"]
}

# List all VNet links for the private DNS zone (only if zone exists)
data "azapi_resource_list" "dns_zone_links" {
  count = local.is_private && length(local.found_dns_zones) > 0 ? 1 : 0
  
  type                   = "Microsoft.Network/privateDnsZones/virtualNetworkLinks@2020-06-01"
  parent_id              = local.found_dns_zones[0].id
  response_export_values = ["*"]
}

