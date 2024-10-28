
# irsa for api service account
module "api_irsa" {
  for_each = {
    for k, v in try(local.irsas.api, {}) : k => v if local.create
  }
  source  = "terraform-aws-modules/iam/aws//modules/iam-role-for-service-accounts-eks"
  version = "5.47.1"

  role_name                      = each.value.role_name
  attach_external_secrets_policy = true

  oidc_providers = {
    one = {
      provider_arn = module.eks[each.value.cluster].oidc_provider_arn
      namespace_service_accounts = flatten([
        for namespace in each.value.namespaces : [
          for service_account in each.value.service_accounts : "${namespace}:${service_account}"
        ]
      ])
    }
  }
}

resource "aws_iam_policy" "api" {
  for_each = merge([
    for k, v in try(local.irsas.api, {}) : {
      for i, statement in v.policies : "${i}-${v.cluster}-${v.role_name}" => {
        Version   = statement.Version
        Statement = statement.Statement
      }
    } if local.create
  ]...)

  policy = jsonencode(each.value)
}

resource "aws_iam_role_policy_attachment" "api" {
  for_each = merge([
    for k, v in try(local.irsas.api, {}) : {
      for i, statement in v.policies : "${i}-${v.cluster}-${v.role_name}" => {
        cluster_name = v.cluster
        role_name    = v.role_name
      }
    } if local.create
  ]...)

  role       = module.api_irsa[each.value.cluster_name].iam_role_name
  policy_arn = aws_iam_policy.api[each.key].arn
}


module "ecr" {
  count   = local.create ? 1 : 0
  source  = "terraform-aws-modules/ecr/aws"
  version = "2.3.0"

  repository_name = "${var.resource_prefix}-ecr"

  repository_read_write_access_arns = [
    module.api_irsa[local.target_cluster].iam_role_arn
  ]

  repository_lifecycle_policy = jsonencode({
    rules = [
      {
        rulePriority = 1,
        description  = "Keep last 30 images",
        selection = {
          tagStatus     = "tagged",
          tagPrefixList = ["v"],
          countType     = "imageCountMoreThan",
          countNumber   = 30
        },
        action = {
          type = "expire"
        }
      }
    ]
  })

  tags = try(merge(local.common_tags, {
    manageECR = "true"
  }))
}