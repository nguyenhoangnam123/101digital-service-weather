module "acm_backend" {
  count   = local.create ? 1 : 0
  source  = "terraform-aws-modules/acm/aws"
  version = "4.0.1"

  domain_name = "${var.environment}.${var.root_domain}"
  subject_alternative_names = [
    "*.${var.environment}.${var.root_domain}"
  ]
  zone_id             = data.aws_route53_zone.main.id
  validation_method   = "DNS"
  wait_for_validation = true

  tags = try(merge(local.common_tags, {
    Name = "${var.resource_prefix}-acm-backend"
  }))
}

data "aws_route53_zone" "main" {
  name = "${var.environment}.${var.root_domain}." # Ensure the domain name ends with a dot
}