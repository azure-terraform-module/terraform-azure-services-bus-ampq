# terraform-azurerm-servicebus

this terraform module provisions an **azure service bus** namespace and its associated resources with support for **private**, **service**, and **public** network modes.

## 1. features
- support for **private**, **service**, and **public** access modes.
- automatic provisioning of **private dns zones** and **virtual network links** if not provided.
- configurable **ip rules** and **vnet rules** for service endpoint mode (applies when `sku = "Premium"`).
- optional creation of **queues** and **topics** inside the namespace.
- system-assigned managed identity on the namespace.
- supports tagging, resource grouping, and subnet customization.

## 2. module usage

### 2.1. prerequisites
ensure that you have the following:
- terraform `>= 1.3`
- azurerm provider `~> 4.25.0`
- proper permissions in your azure subscription to create service bus, dns zones, vnets, and private endpoints.

### 2.2. `network_mode`
specify how the service bus should be exposed:
- `private`: uses private endpoint and private dns zones (no public access).
  
  ![alt text](https://raw.githubusercontent.com/azure-terraform-module/terraform-azure-services-bus-ampq/refs/heads/release/0.0.1/images/01.png)
- `service`: uses service endpoints and ip/vnet rules.
  
	![alt text](https://raw.githubusercontent.com/azure-terraform-module/terraform-azure-services-bus-ampq/refs/heads/release/0.0.1/images/02.png)
- `public`: open to public internet access
  
	![alt text](https://raw.githubusercontent.com/azure-terraform-module/terraform-azure-services-bus-ampq/refs/heads/release/0.0.1/images/03.png)

### 2.3. input variables

| name                              | type            | required | default  | description                                                                                  |
| --------------------------------- | --------------- | -------- | -------- | -------------------------------------------------------------------------------------------- |
| `namespace`                       | `string`        | ✅        | —        | the name of the service bus namespace.                                                       |
| `queues`                          | `list(object({ name = string, partitioning_enabled = optional(bool), requires_duplicate_detection = optional(bool) }))` | ❌ | `[]` | queues to create. defaults: `partitioning_enabled = false`, `requires_duplicate_detection = false`. in Premium, `partitioning_enabled` must be false (enforced). |
| `topics`                          | `list(object({ name = string, partitioning_enabled = optional(bool), requires_duplicate_detection = optional(bool) }))` | ❌ | `[]` | topics to create. defaults: `partitioning_enabled = false`, `requires_duplicate_detection = false`. in Premium, `partitioning_enabled` must be false (enforced). |
| `sku`                             | `string`        | ❌        | `"Premium"` | the sku of the service bus namespace.                                                        |
| `capacity`                        | `number`        | ❌        | `1`      | capacity (messaging units). used only when `sku = "Premium"`; ignored otherwise.             |
| `premium_messaging_partitions`    | `number`        | ❌        | `1`      | premium namespace partition count. used only when `sku = "Premium"`; ignored otherwise.      |
| `network_mode`                    | `string`        | ✅        | —        | network mode: `private`, `service`, `public`.                                                |
| `servicebus_private_dns_zone_ids` | `list(string)`  | ❌        | `[]`     | resource ids of private dns zones for service bus (used in private endpoint mode).           |
| `subnet_ids`                      | `list(string)`  | ❌        | `[]`     | subnet ids used for private endpoints or service endpoints (see network mode behavior).      |
| `vnet_ids`                        | `list(string)`  | ❌        | `[]`     | vnet ids used for linking to private dns zone (only for private endpoints).                  |
| `resource_group_name`             | `string`        | ✅        | —        | resource group where resources will be created.                                              |
| `location`                        | `string`        | ✅        | —        | azure location where resources will be created.                                              |
| `tags`                            | `map(string)`   | ❌        | `{}`     | tags to assign to the resources.                                                             |

#### Notes on `Premium` sku behavior

- When `sku = "Premium"`:
  - Namespace-level `capacity` and `premium_messaging_partitions` are used. If not set, they default to provider defaults.
  - Queue/Topic-level `partitioning_enabled` inputs are treated as non-applicable. The module will fail the plan if these are set to avoid confusion.
  - Partitioning is controlled at the namespace level in Premium.

#### Notes on service mode

- `network_mode = "service"` and `network_mode = "private"` is intended for `sku = "Premium"`. with non-Premium SKUs, this module will not apply network rule sets; consider `public` instead.

### 2.4. example

### variable requirement by `network_mode`
| `network_mode`       | `servicebus_private_dns_zone_ids` | `subnet_ids`              | `vnet_ids` | `ip_rules` |
| -------------------- | --------------------------------- | ------------------------- | ---------- | ---------- |
| **private endpoint** | 🟦                                | ✅ (at least 1)           | ✅         | ❌         |
| **service endpoint** | ❌                                | ✅                        | ❌         | 🟦         |
| **public endpoint**  | ❌                                | ❌                        | ❌         | ❌         |

##### notes:
- ✅ = **required**
- ❌ = **not required**
- 🟦 = **optional**

#### main.tf

network mode - private
- when using private mode, variable `subnet_ids` is where the private endpoint ip will be created. you need at least one subnet id. if `servicebus_private_dns_zone_ids` are not provided, a private dns zone and vnet links will be created and associated.

```hcl
module "servicebus" {
  source  = "<registry-or-repo-url>"
  # e.g., git::https://github.com/<org>/terraform-azure-services-bus-ampq.git?ref=v0.0.1

  # required variables
  namespace            = "my-svcbus-private-mode" # must be unique name
  resource_group_name  = "my-rg"
  location             = "eastus"
  network_mode         = "private"

  subnet_ids = [
    "/subscriptions/xxx/resourceGroups/my-rg/providers/Microsoft.Network/virtualNetworks/my-vnet/subnets/subnet1"
  ]
  vnet_ids = [
    "/subscriptions/xxx/resourceGroups/my-rg/providers/Microsoft.Network/virtualNetworks/my-vnet"
  ]

  # optional variables
  servicebus_private_dns_zone_ids = [
    "/subscriptions/xxx/resourceGroups/my-rg/providers/Microsoft.Network/privateDnsZones/privatelink.servicebus.windows.net"
  ]

  tags = {
    environment = "dev"
    project     = "servicebus-provisioning"
  }

  queues = [
    { name = "queue1" },
    { name = "queue2" }
  ]

  topics = [
    { name = "topic1" },
    { name = "topic2" }
  ]
}
```

network mode - service

```hcl
module "servicebus" {
  source  = "<registry-or-repo-url>"

  # required variables
  namespace            = "my-svcbus-service-mode"
  resource_group_name  = "my-rg"
  location             = "eastus"
  network_mode         = "service"
  sku                  = "Premium"

  subnet_ids = [
    "/subscriptions/xxx/resourceGroups/my-rg/providers/Microsoft.Network/virtualNetworks/my-vnet/subnets/subnet1"
  ]


  tags = {
    environment = "dev"
    project     = "servicebus-provisioning"
  }

  queues = [
    { name = "queue1", requires_duplicate_detection = true },
    { name = "queue2", requires_duplicate_detection = false }
  ]

  topics = [
    { name = "topic1" },
    { name = "topic2" }
  ]
}
```

network mode - public
```hcl
module "servicebus" {
  source  = "<registry-or-repo-url>"

  namespace            = "my-svcbus-public-mode"
  resource_group_name  = "my-rg"
  location             = "eastus"
  network_mode         = "public"
  sku                  = "Standard"

  tags = {
    environment = "dev"
    project     = "servicebus-provisioning"
  }

  queues = [
    { name = "queue1", partitioning_enabled = false, requires_duplicate_detection = true },
    { name = "queue2", partitioning_enabled = false, requires_duplicate_detection = false }
  ]

  topics = [
    { name = "topic1", partitioning_enabled = false, requires_duplicate_detection = true },
    { name = "topic2", partitioning_enabled = false, requires_duplicate_detection = false }
  ]
}
```

#### provider.tf
```hcl
terraform {
  required_version = ">= 1.9, < 2.0"
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "4.25.0"
    }
  }
  backend "azurerm" {
    resource_group_name  = "<your-resource-group-name>"
    storage_account_name = "<your-storage-account-name>"
    container_name       = "<your-container-name>"
    key                  = "<your-key>"
    subscription_id      = "<your-subscription-id>"
  }
}

provider "azurerm" {
  features {}
  subscription_id = "<your-subscription-id>"
}
```

#### outputs.tf
```hcl
output "namespace" {
  description = "the name of the service bus namespace"
  value       = module.servicebus.namespace
}

output "namespace_id" {
  description = "the id of the service bus namespace"
  value       = module.servicebus.namespace_id
}

output "hostname" {
  description = "the hostname of the service bus namespace"
  value       = module.servicebus.hostname
}
 
output "queue_names" {
  description = "names of service bus queues created"
  value       = module.servicebus.queue_names
}
 
output "queues" {
  description = "map of queue name to queue id"
  value       = module.servicebus.queues
}
 
output "topic_names" {
  description = "names of service bus topics created"
  value       = module.servicebus.topic_names
}
 
output "topics" {
  description = "map of topic name to topic id"
  value       = module.servicebus.topics
}
```
