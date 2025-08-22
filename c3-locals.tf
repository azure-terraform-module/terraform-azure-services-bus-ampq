locals {
  # Get subnet names from subnet IDs
  subnet_info = {
    for subnet_id in var.subnet_ids : subnet_id => {
      name = try(element(split("/", subnet_id), length(split("/", subnet_id)) - 1), "subnet-${substr(md5(subnet_id), 0, 8)}")
    } 
  }

  rg_name_lower = lower(var.resource_group_name)

  private_dns_zone_name = "privatelink.servicebus.windows.net"

  # Create private DNS zone if not provided, and network mode is private and not exist in the resource group
  create_private_dns_zone = var.network_mode == "private" && try(data.azurerm_private_dns_zone.private_dns_zone.id, null) == null
  
  # Extract VNet link info from the API response
  vnet_links = local.is_private && length(data.azapi_resource_list.dns_zone_links) > 0 ? [
    for link in data.azapi_resource_list.dns_zone_links[0].output.value : {
      name               = link.name
      id                 = link.id
      virtual_network_id = link.properties.virtualNetwork.id
      registration_enabled = try(link.properties.registrationEnabled, false)
    }
  ] : []
  
  # Find which VNets already have links (return VNet IDs that have existing links)
  # Exclude links managed by this module (with our naming pattern)
  vnets_with_existing_links = length(local.vnet_links) > 0 ? [
    for link in local.vnet_links : link.virtual_network_id 
    if !startswith(link.name, "${var.namespace}-tf-managed-vnet-link")
  ] : []
  
  # Find VNets that need links (VNets provided but don't have existing NON-TERRAFORM-MANAGED links)
  vnets_needing_links = [
    for vnet_id in var.vnet_ids : vnet_id if !contains(local.vnets_with_existing_links, vnet_id)
  ]

  # Endpoint types
  is_private = var.network_mode == "private" # Private endpoint - Traffic in VNet 
  is_service = var.network_mode == "service" # Service endpoint - Traffic in Azure backbone 
  is_public  = var.network_mode == "public"  # Public endpoint  - Traffic over the internet

  public_network_access = local.is_private ? false : (local.is_service || local.is_public)

  # Network rulesets - Service endpoints
  network_rulesets = {
    default_action                 = local.is_public ? "Allow" : "Deny" # If use public endpoint, must allow all traffic
    trusted_services_allowed = true
    public_network_access_enabled  = local.public_network_access
  }
}