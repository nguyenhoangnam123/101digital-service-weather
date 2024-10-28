locals {
  create = true
  common_tags = {
    Terraform   = "true"
    Environment = var.environment
  }
}