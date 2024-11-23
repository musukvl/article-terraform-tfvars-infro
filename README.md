---
title: Multi-environment with terraform variables file
published: true
description: The article describes the approach to manage multi-environment Terraform codebase with `.tfvars` files.
tags: terraform
canonical_url: null
id: 2118591
date: '2024-11-23T18:36:19Z'
cover_image: ./logo.jpg
---

In our company we have thousands of resources managed by Terraform. Which are deployed to multiple environments (dev, staging, production) and different regions.

The key principles we have for our Terraform codebase are:
1. Use the same Terraform codebase (.tf files) for all environments (dev, stage, prod).
2. All environment specific settings should be managed via Terraform variable files (.tfvars).

Below is an our typical Terraform codebase structure:

```tree
src/
├── environments/
│   ├── dev.tfvars
│   ├── stage.tfvars
│   └── prod.tfvars
├── variables.tf
├── db_server.tf
├── main.tf
├── terraform.tf
├── providers.tf
└── ...
```

`variables.tf` file contains the variables definitions:
```hcl
variable "resource_group_name" {
  description = "The resource group name to deploy db server"
  type = string
}

variable "location" {
  description = "The db server location"
  type = string
}

variable "enable_replication" {
  description = "Enable DB replication of resources to other region"
  type = bool
}
```

`src/environments/dev.tfvars` contains the environment specific settings:


```hcl
resource_group_name = "rg-dev"
location = "eastus"
enable_replication = false
```

Each environment has corresponding terraform state. So we need to specify the state file and `.tfvars` file to run `terraform apply` command for specific environment:

```bash
terraform apply -var-file="src/environments/dev.tfvars" -state="dev.tfstate"
terraform apply -var-file="src/environments/stage.tfvars" -state="stage.tfstate"
terraform apply -var-file="src/environments/prod.tfvars" -state="prod.tfstate"
```

If you use terraform cloud, you probably need to specify workspace name with `TF_WORKSPACE` environment variable instead of state file.

![Terraform Variables and State Flow](https://raw.githubusercontent.com/musukvl/article-terraform-tfvars-infro/refs/heads/main/tfvars.png)

# Feature flags

The Terraform variables file can also store feature flags together with terraform modules.


This approach allows to test the Terraform code in the dev and stage environment before it is applied to other environments. If staging and production environments have the same settings we can have the same code coverage for production.

Terraform has no if-else logic, so the only way to implement feature flags is to use `for_each` and `count` statements. 

In the following example we create an azure resource group and role assignments if the `enable_replication` variable is `true`:

```hcl
variable "enable_replication" {
  type = bool
}

resource "azurerm_resource_group" "replica_rg" {
  count = var.enable_replication ? 1 : 0
  name     = "replica-rg"
  location = var.location   
}

resource "azurerm_role_assignment" "role_assignments" {
  count = var.enable_replication ? 1 : 0
  scope                = azurerm_resource_group.replica_rg[0].id
  role_definition_name = "Contributor"
  principal_id         = "12345678-1234-1234-1234-123456789"  
}
```

This approach is not perfect, because count condition should be added to each dependent resource. Better to group dependent resources into the local module, to have a single count condition for entire module. For example:

```hcl
variable "enable_replication" {
  type = bool
}

module "replica_rg" {
  source = "./modules/replica_rg"
  count = var.enable_replication ? 1 : 0
  rg_name     = "replica-rg"
  contributor_id = "12345678-1234-1234-1234-123456789"
}
```

# Terraform variables as DSL

The terraform variables definitions becomes another layer of abstraction: instead of defining particular resources we define business entities and feature settings. 
In fact, `.tfvars` files management becomes programming on DSL language defined by terraform variables blocks..
For example, the definition for CI/CD build agents: 

`variables.tf`:
```hcl
variable "build_agents" {
  description = "Build agents settings"
  type = map(object({
    number_of_vms = number
    vm_size = optional(string, "Standard_N2_v2")
    private_network_access = optional(bool, false) # limit access to agent vms
  }))
}
```

`dev.tfvars`:
```hcl
build_agents = {    
    build_pool = {
        number_of_vms = 10
        vm_size = "Standard_D2_v2"
        private_network_access = false
    }
    deployment_pool = {
        number_of_vms = 5
        vm_size = "Standard_D2_v2"
        private_network_access = true
    }
}
```
Here we are not defining azure resources, but our infrastructure assets, which, in fact could be implemented differently.

## Control interface

The `.tfvars` approach allows to define the control interface for infrastructure operators.
So the settings in `.tfvars` are working like control panel in pilot cockpit hiding the underlying resources and their dependencies. 
For example, if ci/cd admin needs to increase number of agents he don't need to search for resources he needs to reconfigure in terraform codebase. He just changes the `number_of_vms` in `.tfvars` file.

## Refactoring

Naming for the terraform variables and object properties is a challenge. 
Time to time we need to do refactoring of variables to change objects structure, or introduce the new properties for all objects. Which also leads changes in all `.tfvars` files and states.

Normally, such refactoring has the following steps:

1. Modifying variables definitions in `variables.tf` file.
2. Modifying all `.tfvars` files.
3. Modifying terraform code to support the changes.
4. Generating [moved blocks](https://developer.hashicorp.com/terraform/language/moved) in terraform code.

For `.tfvars` modification and code generation you can  use python libraries like
[python-hcl2](https://pypi.org/project/python-hcl2).
Unfortunately, hcl2 parsers are not available for many other languages, so previously I converted `.tfvars` to json and used json as an intermediate format.
I used this go application which is a wrapper over official Hashicorp hcl2 go library: [https://github.com/musukvl/tfvars-parser](https://github.com/musukvl/tfvars-parser) 

Recently I created my own C# dotnet library to work with `.tfvars` files: [amba-tfvars](https://github.com/musukvl/amba-tfvars). 
The library focused on `.tfvars` file refactoring. 
It can extract not only terraform variables data, but also code comments from `.tfvars` files, which could be very important to keep during the `.tfvars` files transformation.
Sometimes it is important to keep original formatting so the library collects information about original maps and lists code style: if they were one-liners, or each property has its own line.

# Conclusion

I think the `.tfvars` files approach is a good way to manage multi-environment Terraform codebase for huge projects. It allows naturally to implement feature flags and truck based development for Infrastructure as Code.

The article repository: [https://github.com/musukvl/article-terraform-tfvars-infro](https://github.com/musukvl/article-terraform-tfvars-infro)
