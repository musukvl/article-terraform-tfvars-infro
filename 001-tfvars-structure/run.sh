#! /bin/bash

terraform init
terraform plan -var-file="environments/prod.tfvars" -state="prod.tfstate"

