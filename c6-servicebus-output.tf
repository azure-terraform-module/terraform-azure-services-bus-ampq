output "namespace_id" {
  description = "The ID of the Service Bus Namespace"
  value       = azurerm_servicebus_namespace.servicebus_namespace.id
}

output "namespace" {
  description = "The name of the Service Bus Namespace"
  value       = azurerm_servicebus_namespace.servicebus_namespace.name
}

output "hostname" {
  description = "The hostname of the Service Bus Namespace"
  value       = "${azurerm_servicebus_namespace.servicebus_namespace.name}.servicebus.windows.net"
}

output "queue_names" {
  description = "Names of Service Bus queues created"
  value       = keys(azurerm_servicebus_queue.servicebus_queue)
}

output "queues" {
  description = "Map of queue name to queue ID"
  value       = { for name, q in azurerm_servicebus_queue.servicebus_queue : name => q.id }
}

output "topic_names" {
  description = "Names of Service Bus topics created"
  value       = keys(azurerm_servicebus_topic.servicebus_topic)
}

output "topics" {
  description = "Map of topic name to topic ID"
  value       = { for name, t in azurerm_servicebus_topic.servicebus_topic : name => t.id }
}

output "private_dns_zone_id" {
  description = "The Private DNS Zone ID used for the private endpoint (existing or created)."
  value       = try(data.azurerm_private_dns_zone.private_dns_zone.id, azurerm_private_dns_zone.private_dns_servicebus[0].id, null)
}

output "private_dns_zone_vnet_links_info" {
  description = "Information about VNet links for the Private DNS Zone."
  value = {
    vnets_with_existing_links = local.vnets_with_existing_links
    vnets_needing_links      = local.vnets_needing_links
    all_existing_links       = local.vnet_links
  }
}

output "all_dns_zone_vnet_links" {
  description = "All Virtual Network Links for the Private DNS Zone."
  value = local.vnet_links
}

# Temporary output to debug local values
# output "debug_locals" {
#   description = "Debug information for local values."
#   value = {
#     create_private_dns_zone = local.create_private_dns_zone
#     is_private              = local.is_private
#     dns_zone_exists        = try(data.azurerm_private_dns_zone.private_dns_zone.id, null) != null
#     vnets_needing_links_count = length(local.vnets_needing_links)
#     vnets_with_links_count    = length(local.vnets_with_existing_links)
#   }
# }
