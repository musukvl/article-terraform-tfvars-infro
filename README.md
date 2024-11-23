---
title: Multi-environment with terraform variables file
published: true
description: Multi-environment with terraform variables file
tags: terraform
canonical_url: null
id: 2118591
date: '2024-11-23T18:36:19Z'
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

The .tfvars files contains environment specific settings, for example,
`src/environments/dev.tfvars` content:
```hcl
resource_group_name = "rg-dev"
location = "eastus"
enable_replication = false
```

Each environment has corresponding terraform state.

```
The `terraform apply` command to run apply for specific environment will be:
```bash

terraform apply -var-file="src/environments/dev.tfvars" -state="dev.tfstate"
terraform apply -var-file="src/environments/stage.tfvars" -state="stage.tfstate"
terraform apply -var-file="src/environments/prod.tfvars" -state="prod.tfstate"

```

![Terraform Variables and State Flow](https://raw.githubusercontent.com/musukvl/article-terraform-tfvars-infro/refs/heads/main/tfvars.png)

# Feature flags

The Terraform variables file can also store feature flags together with terraform modules.


This approach allows to test the Terraform code in the dev and stage environment before it is applied to other environments. If staging and production environments have the same settings we can have the same code coverage for production.


