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

