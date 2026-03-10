# Fancia

Fancia is a social platform connecting people with shared interests for offline, in-person group gatherings and community building.

## infra

This repository contains Terraform code to provision the infrastructure of Fancia.

### IMPORTANT

It is recommended to use fancia-infra-pipeline to deploy the infrastructure.

### Prerequisites

- AWS CLI installed and configured for the target account and profile
- Terraform installed

### Quick start (local deployment)

1. Define the profile and project name to be used for deployment:

   ```bash
   export AWS_PROFILE=<your-aws-profile>
   export PROJECT_NAME=<your-project-name>
   ```

2. Initialize Terraform state (adjust backend bucket name as needed):

   ```bash
   terraform init -backend-config="bucket=${PROJECT_NAME}-infra-pipeline-terraform-state"
   ```

3. Plan and apply the infrastructure (use a local terraform.tfvars for environment values):

   ```bash
   terraform plan -var-file="terraform.tfvars"
   terraform apply -var-file="terraform.tfvars"
   ```

### Notes

- Update variables in `terraform.tfvars` (project_name, region, profile, GitHub connection details, and infra_credentials) before applying. Create a local `terraform.tfvars` file if it does not exist and ensure it is not checked into version control.
