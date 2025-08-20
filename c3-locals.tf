locals {
  # Get subnet names from subnet IDs
  subnet_info = {
    for subnet_id in var.subnet_ids : subnet_id => {
      name = try(element(split("/", subnet_id), length(split("/", subnet_id)) - 1), "subnet-${substr(md5(subnet_id), 0, 8)}")
    } 
  }

  # Endpoint types
  is_private = var.network_mode == "private" # Private endpoint - Traffic in VNet 
  is_service = var.network_mode == "service" # Service endpoint - Traffic in Azure backbone 
  is_public  = var.network_mode == "public"  # Public endpoint  - Traffic over the internet

  # Public network access - Service endpoints, Public endpoints
  public_network_access = local.is_private ? false : (local.is_service || local.is_public)

  # Determine whether to create the private DNS zone (no ID provided)
  create_private_dns_zone = local.is_private && (var.private_dns_zone_id == null || trimspace(var.private_dns_zone_id) == "")

  # User-provided private DNS zone (parsed components)
  user_dns_zone_id   = !local.create_private_dns_zone && var.private_dns_zone_id != null && trimspace(var.private_dns_zone_id) != "" ? var.private_dns_zone_id : null
  user_dns_zone_rg   = local.user_dns_zone_id != null ? element(split("/", local.user_dns_zone_id), 4) : null
  user_dns_zone_name = local.user_dns_zone_id != null ? element(split("/", local.user_dns_zone_id), 8) : null

  # Effective private DNS zone IDs (list) for PE attachment
  private_dns_zone_ids = local.is_private ? (
    local.create_private_dns_zone
    ? [azurerm_private_dns_zone.private_dns_servicebus[0].id]
    : (local.user_dns_zone_id != null ? [local.user_dns_zone_id] : [])
  ) : []

  # Network rulesets - Service endpoints
  network_rulesets = [
    {
      default_action                 = local.is_public ? "Allow" : "Deny" # If use public endpoint, must allow all traffic
      trusted_services_allowed = true
      public_network_access_enabled  = local.public_network_access

      # Vnet rules - Service endpoints
      virtual_network_rule = local.is_service ? [
        for subnet_id in var.subnet_ids : {
          subnet_id                                       = subnet_id
          ignore_missing_virtual_network_service_endpoint = true
        }
      ] : []
    }
  ]

}

