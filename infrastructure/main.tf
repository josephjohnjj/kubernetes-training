############################################
# Terraform Configuration Block
# This section defines Terraform requirements
# and provider setup for AWS.
############################################

terraform {
  # --------------------------------------------
  # Required Providers
  # --------------------------------------------
  required_providers {
    aws = {
      # Specifies the source registry for the AWS provider plugin
      source = "hashicorp/aws"

      # Version constraint: requires version 5.0 or newer,
      # but compatible with versions >= 5.0 (including patch updates)
      version = ">= 5.0"
    }
  }

  # --------------------------------------------
  # Required Terraform CLI Version
  # --------------------------------------------
  # Ensures that Terraform CLI version 1.2.0 or newer is used
  required_version = ">= 1.2.0"

  # --------------------------------------------
  # Terraform Cloud Configuration (Optional)
  # --------------------------------------------
  cloud {
    # The Terraform Cloud organization to connect with
    organization = "jxj900"

    # Workspace configuration in Terraform Cloud
    workspaces {
      # Name of the workspace to use for state management
      name = "slurm-cluster"
    }
  }
}

# --------------------------------------------
# AWS Provider Configuration
# --------------------------------------------

provider "aws" {
  # The AWS region where resources will be created
  region = "us-east-1"
}
