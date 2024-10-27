locals {
  vpcs = {
    api = {
      name = "${var.resource_prefix}-eks-vpc"
      cidr = "10.0.0.0/16"
      azs = [
        for i in ["a", "b", "c"] : "${var.region}${i}"
      ]
      private_subnets = [
        for i in [1, 2, 3] : "10.0.${i}.0/24"
      ]
      public_subnets = [
        for i in [1, 2, 3] : "10.0.10${i}.0/24"
      ]
    }
  }
}

module "vpc" {
  for_each = {
    for k, v in local.vpcs : k => v if local.create
  }
  source = "terraform-aws-modules/vpc/aws"

  name = each.value.name
  cidr = each.value.cidr

  azs             = each.value.azs
  private_subnets = each.value.private_subnets
  public_subnets  = each.value.public_subnets

  enable_nat_gateway = try(each.value.enable_nat_gateway, true)
  single_nat_gateway = try(each.value.single_nat_gateway, true)
  enable_vpn_gateway = try(each.value.enable_vpn_gateway, false)

  tags = try(merge(local.common_tags, each.value.tags), local.common_tags)
}