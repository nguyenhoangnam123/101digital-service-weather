remote_state {
  backend = "s3"
  generate = {
    path      = "backend.tf"
    if_exists = "overwrite_terragrunt"
  }
  config = {
    bucket = "mightystingbee-101digital-assignment-terraform-state"
    key = "${path_relative_to_include()}/terraform.tfstate"
    dynamodb_table = "mightystingbee-101digital-assignment-terraform-lock"
    encrypt        = true
    region = "us-east-1"
  }
}

generate "provider" {
  path = "versions.tf"
  if_exists = "overwrite_terragrunt"
  contents = <<EOF
    terraform {
      required_providers {
        aws = {
          source = "hashicorp/aws"
          version = "~> 5.73.0"
        }
        kubernetes = {
          source  = "hashicorp/kubernetes"
          version = ">= 2.25.2"
        }
        helm = {
          source  = "hashicorp/helm"
          version = ">= 2.9"
        }
        sops = {
          source = "carlpett/sops"
          version = "1.1.1"
        }                
      }
    }
    provider "aws" {
      region = "us-east-1"
      # assume_role {
      #   role_arn = "arn:aws:iam::203918846720:role/mightystingbee-101digital-assignment-terraform-role"
      # }
    }
    provider "sops" {
      # Configuration options
    }
    EOF
}