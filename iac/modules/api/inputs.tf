variable "environment" {
  description = "Environment name"
  default     = "dev"
}

variable "region" {
  description = "AWS region where resources provisioned"
  default     = "us-east-1"
}

variable "resource_prefix" {
  description = "Prefix for resources created"
  default     = "mightystingbee"
}

variable "terraform_admin_user_name" {
  description = "value to be appended to the terraform admin user name"
  default     = "terraform-admin"
}

variable "root_domain" {
  default = "mightybee.dev"
}


