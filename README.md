# Terraform Infrastructure for WWT Web Services

This repository contains [Terraform] files that define the infrastructure for a
large portion of the [WorldWide Telescope][home] web services. In principle,
you could use these templates to create your own clone of the WWT web app,
although the WWT team does not test the templates for this kind of portability,
and various secrets and data holdings are not expressed in these files.

[Terraform]: https://www.terraform.io/
[home]: https://worldwidetelescope.org/home/

Basic commands:

```
terraform plan -var-file=prod.tfvars                        # plan a change
terraform apply -var-file=prod.tfvars                       # apply a change
terraform import -var-file=prod.tfvars [tfname] [azurename] # tell Terraform about a resource
```

Directory structure:

- `prod` expresses much, but not all, of the production WWT environment
- `dev` expresses a more limited development environment

The eventual goal is to merge `dev` and `prod`, and have the distinctions
entirely subsumed into the `.tfvars` files, but that is unlikely to happen
anytime soon.


## Updating the Terraform provider version

Do this often, since it's always evolving.

- Remove `.terraform.lock.hcl`
- Update the version in the `main.tf` file
  - Latest version identified here: https://registry.terraform.io/providers/hashicorp/azurerm/latest
- Run `terraform init`
- Run `terraform (plan|apply) -var-file=prod.tfvars -refresh-only`
