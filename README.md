# Terraform-azurerm-servicebus

This Terraform module provisions an **Azure Service Bus** namespace and its associated resources with support for **private**, **service**, and **public** network modes.

## 1. Features
- Support for **private**, **service**, and **public** access modes.
- **Intelligent private DNS zone management**: automatically discovers existing `privatelink.servicebus.windows.net` zone or creates new one.
- **Smart VNet link detection**: discovers existing VNet links and only creates missing ones to prevent conflicts.
- Configurable **IP rules** and **VNet rules** for service endpoint mode (applies when `sku = "Premium"`).
- Optional creation of **queues** and **topics** inside the namespace.
- System-assigned managed identity on the namespace.
- Supports tagging, resource grouping, and subnet customization.

## 2. module usage

### 2.1. prerequisites
Ensure that you have the following:
- Terraform `>= 1.5`
- azurerm provider `~> 4.25.0`
- azapi provider `>= 1.0.0`
- Proper permissions in your Azure subscription to create Service Bus, DNS zones, VNets, and private endpoints.

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
| `namespace`                       | `string`        | ✅        | —        | The name of the Service Bus namespace.                                                       |
| `resource_group_name`             | `string`        | ✅        | —        | Resource group where resources will be created.                                              |
| `location`                        | `string`        | ✅        | —        | Azure location where resources will be created.                                              |
| `subscription_id`                 | `string`        | ✅        | —        | The Azure subscription ID (used to construct Azure resource IDs for azapi data sources).     |
| `queues`                          | `list(object({ name = string, partitioning_enabled = optional(bool), requires_duplicate_detection = optional(bool) }))` | ❌ | `[]` | Queues to create. Defaults: `partitioning_enabled = false`, `requires_duplicate_detection = false`. In Premium, `partitioning_enabled` must be false (enforced). |
| `topics`                          | `list(object({ name = string, partitioning_enabled = optional(bool), requires_duplicate_detection = optional(bool) }))` | ❌ | `[]` | Topics to create. Defaults: `partitioning_enabled = false`, `requires_duplicate_detection = false`. In Premium, `partitioning_enabled` must be false (enforced). |
| `sku`                             | `string`        | ❌        | `"Premium"` | The SKU of the Service Bus namespace.                                                        |
| `capacity`                        | `number`        | ❌        | `1`      | Capacity (messaging units). Used only when `sku = "Premium"`; ignored otherwise.             |
| `premium_messaging_partitions`    | `number`        | ❌        | `null`   | Premium namespace partition count. Used only when `sku = "Premium"`; ignored otherwise.      |
| `network_mode`                    | `string`        | ❌        | `"public"` | Network mode: `private`, `service`, `public`.                                                |
| `vnet_ids`                        | `list(string)`  | ❌        | `[]`     | VNet IDs used for linking to private DNS zone (only for private endpoints).                  |
| `subnet_ids`                      | `list(string)`  | ❌        | `[]`     | Subnet IDs used for private endpoints or service endpoints (see network mode behavior).      |
| `local_auth_enabled`              | `bool`          | ❌        | `false`  | Whether to enable local (SAS) auth. Set to `false` to enforce Entra ID only.                 |
| `customer_managed_key`            | `object({ key_vault_key_id = string, user_assigned_identity_id = string })` | ❌ | `null` | CMK for encryption at rest (Premium only). Requires a managed identity with key vault access. |
| `tags`                            | `map(string)`   | ❌        | `{}`     | Tags to assign to the resources.                                                             |

#### Notes on `Premium` SKU behavior

- When `sku = "Premium"`:
  - Namespace-level `capacity` and `premium_messaging_partitions` are used. If not set, they default to provider defaults.
  - Queue/Topic-level `partitioning_enabled` inputs are treated as non-applicable. The module will fail the plan if these are set to avoid confusion.
  - Partitioning is controlled at the namespace level in Premium.

#### Notes on service mode

- `network_mode = "service"` applies network rules only when `sku = "Premium"`. With non-Premium SKUs, network rules are not applied by this module; consider `public` or use `private` endpoints instead.

### 2.4. intelligent private DNS zone management

When using `network_mode = "private"`, the module intelligently manages private DNS zones and VNet links:

#### 🔍 **Discovery Logic**
1. **Searches for existing DNS zone** named `privatelink.servicebus.windows.net` in the specified resource group
2. **Discovers existing VNet links** for the DNS zone using Azure API (`azapi_resource_list`)
3. **Identifies which VNets need new links** by comparing your `vnet_ids` with existing links

#### 🎯 **Creation Logic**
- **DNS zone**: Creates new zone only if none exists with the specified name
- **VNet links**: Creates links only for VNets that don't already have them
- **Naming**: Uses unique names like `{namespace}-tf-managed-vnet-link-0` to avoid conflicts

#### ✅ **Benefits**
- **No conflicts**: Prevents "VNet already linked" errors
- **Multi-module safe**: Multiple Service Bus modules can safely use same DNS zone
- **Idempotent**: Running multiple times won't cause issues
- **Automatic discovery**: Finds existing infrastructure without manual input

#### 📊 **Debug Outputs**
The module provides debug outputs to help you understand what's happening:

```hcl
# See what the module discovered/created
output "dns_debug" {
  value = module.servicebus.debug_locals
}

output "vnet_links_info" {
  value = module.servicebus.private_dns_zone_vnet_links_info
}
```

### 2.5. Examples

#### Variable requirements by `network_mode`
| `network_mode`       | `subnet_ids`              | `vnet_ids` | 
| -------------------- | ------------------------- | ---------- | 
| **private endpoint** | ✅ (at least 1)           | ✅         |
| **service endpoint** | ✅                        | ❌         |
| **public endpoint**  | ❌                        | ❌         | 

#### Notes:
- ✅ = **required**
- ❌ = **not required**

#### main.tf

**Network mode - private**
- When using private mode, variable `subnet_ids` is where the private endpoint IP will be created. You need at least one subnet ID.
- The module automatically discovers existing `privatelink.servicebus.windows.net` DNS zone or creates a new one.
- VNet links are intelligently managed: existing links are discovered and only missing ones are created to prevent conflicts.

```hcl
module "servicebus" {
  source  = "<registry-or-repo-url>"
  # e.g., git::https://github.com/<org>/terraform-azure-services-bus-ampq.git?ref=v0.0.1

  # required variables
  namespace            = "my-svcbus-private-mode" # must be unique name
  resource_group_name  = "my-rg"
  location             = "eastus"
  subscription_id      = "<your-subscription-id>" # required by azapi data sources
  network_mode         = "private"

  subnet_ids = [
    "/subscriptions/xxx/resourceGroups/my-rg/providers/Microsoft.Network/virtualNetworks/my-vnet/subnets/subnet1"
  ]
  vnet_ids = [
    "/subscriptions/xxx/resourceGroups/my-rg/providers/Microsoft.Network/virtualNetworks/my-vnet"
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

**Network mode - service**

```hcl
module "servicebus" {
  source  = "<registry-or-repo-url>"

  # required variables
  namespace            = "my-svcbus-service-mode"
  resource_group_name  = "my-rg"
  location             = "eastus"
  subscription_id      = "<your-subscription-id>"
  network_mode         = "service"
  sku                  = "Premium"

  subnet_ids = [
    "/subscriptions/xxx/resourceGroups/my-rg/providers/Microsoft.Network/virtualNetworks/my-vnet/subnets/subnet1"
  ]

  # encryption with customer-managed key (Premium)
  customer_managed_key = {
    key_vault_key_id          = "/subscriptions/xxx/resourceGroups/my-kv-rg/providers/Microsoft.KeyVault/vaults/my-kv/keys/my-sb-key"
    user_assigned_identity_id = "/subscriptions/xxx/resourceGroups/my-rg/providers/Microsoft.ManagedIdentity/userAssignedIdentities/sb-kv-mi"
  }

  tags = {
    environment = "dev"
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

**Network mode - public**

```hcl
module "servicebus" {
  source  = "<registry-or-repo-url>"

  # required variables
  namespace            = "my-svcbus-public-mode"
  resource_group_name  = "my-rg"
  location             = "eastus"
  subscription_id      = "<your-subscription-id>"
  network_mode         = "public"
  sku                  = "Standard"

  local_auth_enabled = true

  tags = {
    environment = "dev"
    project     = "servicebus-provisioning"
  }

  queues = [
    { 
      name = "test-queue",
      requires_duplicate_detection = true
      partitioning_enabled = true # Only for Standard SKU
    }
  ]

  topics   = [
    {
      name = "test-topic",
      requires_duplicate_detection = true
      partitioning_enabled = true # Only for Standard SKU
    }
  ]
}
```

#### provider.tf
```hcl
terraform {
  required_version = ">= 1.5, < 2.0"
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 4.25.0"
    }
    azapi = {
      source  = "azure/azapi"
      version = ">= 1.0.0"
    }
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
  description = "The name of the Service Bus namespace"
  value       = module.servicebus.namespace
}

output "namespace_id" {
  description = "The ID of the Service Bus namespace"
  value       = module.servicebus.namespace_id
}

output "hostname" {
  description = "The hostname of the Service Bus namespace"
  value       = module.servicebus.hostname
}
 
output "queue_names" {
  description = "Names of Service Bus queues created"
  value       = module.servicebus.queue_names
}
 
output "queues" {
  description = "Map of queue name to queue ID"
  value       = module.servicebus.queues
}
 
output "topic_names" {
  description = "Names of Service Bus topics created"
  value       = module.servicebus.topic_names
}
 
output "topics" {
  description = "Map of topic name to topic ID"
  value       = module.servicebus.topics
}

# DNS zone management outputs
output "private_dns_zone_id" {
  description = "The Private DNS Zone ID used (existing or created)"
  value       = module.servicebus.private_dns_zone_id
}

output "private_dns_zone_vnet_links_info" {
  description = "Information about VNet links management"
  value       = module.servicebus.private_dns_zone_vnet_links_info
}

output "debug_locals" {
  description = "Debug information for troubleshooting"
  value       = module.servicebus.debug_locals
}
```
