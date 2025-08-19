output "namespace_name" {
  description = "The name of the Service Bus Namespace"
  value       = azurerm_servicebus_namespace.servicebus_namespace.name
}

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

