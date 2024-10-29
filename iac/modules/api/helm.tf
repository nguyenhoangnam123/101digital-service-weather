
data "aws_ecrpublic_authorization_token" "token" {}

# Get secrets from SOPS encrypted file
data "sops_file" "secrets" {
  source_file = "${path.module}/secrets/secrets.${var.environment}.encrypted.yaml"
}

provider "kubernetes" {
  host                   = module.eks[local.target_cluster].cluster_endpoint
  cluster_ca_certificate = base64decode(module.eks[local.target_cluster].cluster_certificate_authority_data)

  exec {
    api_version = "client.authentication.k8s.io/v1beta1"
    command     = "aws"
    args        = ["eks", "get-token", "--cluster-name", module.eks[local.target_cluster].cluster_name, "--region", var.region]
  }
}

provider "helm" {
  kubernetes {
    host                   = module.eks[local.target_cluster].cluster_endpoint
    cluster_ca_certificate = base64decode(module.eks[local.target_cluster].cluster_certificate_authority_data)

    exec {
      api_version = "client.authentication.k8s.io/v1beta1"
      command     = "aws"
      args        = ["eks", "get-token", "--cluster-name", module.eks[local.target_cluster].cluster_name, "--region", var.region]
    }
  }
}

locals {
  target_cluster = "api"
  helm_releases = {
    karpenter = {
      namespace        = "karpenter"
      create_namespace = true
      repository       = "oci://public.ecr.aws/karpenter"
      chart            = "karpenter"
      version          = "v0.31.3"

      value_files = []
      overriden_values = [
        {
          name  = "settings.aws.clusterName"
          value = module.eks[local.target_cluster].cluster_name
        },
        {
          name  = "settings.aws.clusterEndpoint"
          value = module.eks[local.target_cluster].cluster_endpoint
        },
        {
          name  = "serviceAccount.annotations.eks\\.amazonaws\\.com/role-arn"
          value = module.karpenter[local.target_cluster].iam_role_arn
        },
        {
          name  = "settings.aws.defaultInstanceProfile"
          value = module.karpenter[local.target_cluster].instance_profile_name
        },
        {
          name  = "settings.aws.interruptionQueueName"
          value = module.karpenter[local.target_cluster].queue_name
        }
      ]
    }
    ingressnginx = {
      namespace        = "ingress-nginx"
      create_namespace = true
      repository       = "https://kubernetes.github.io/ingress-nginx"
      chart            = "ingress-nginx"
      version          = "4.10.0"

      value_files = [
        templatefile("${path.module}/helms/ingress-nginx.yaml.tftpl", {})
      ]
      overriden_values = [
        {
          name  = "controller.service.annotations.service\\.beta\\.kubernetes\\.io/aws-load-balancer-ssl-cert"
          value = module.acm_backend[0].acm_certificate_arn
        },
      ]
    }
    certmanager = {
      namespace        = "cert-manager"
      create_namespace = true
      repository       = "https://charts.jetstack.io"
      chart            = "cert-manager"
      version          = "1.16.1"
    }
    # external-secret
    externalsecrets = {
      release_name     = "externalsecret"
      repository       = "https://charts.external-secrets.io/"
      chart            = "external-secrets"
      version          = "0.10.5"
      namespace        = "external-secrets"
      create_namespace = true
      overriden_values = [
        {
          name  = "serviceAccount.name"
          value = "external-secrets"
        },
        {
          name  = "serviceAccount.annotations.eks\\.amazonaws\\.com/role-arn"
          value = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/external-secrets"
        },
      ]
    }
    # externaldns
    externaldns = {
      release_name = "externaldns"
      repository   = "https://kubernetes-sigs.github.io/external-dns/"
      chart        = "external-dns"
      version      = "1.15.0"
      namespace    = "external-dns"
      overriden_values = [
        {
          name  = "serviceAccount.name"
          value = "external-dns"
        },
        {
          name  = "serviceAccount.annotations.eks\\.amazonaws\\.com/role-arn"
          value = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/external-dns"
        },
      ]
    }
    api = {
      namespace = "default"
      chart     = "./helms/api"
      version   = "0.1.0"
      lint      = true

      value_files = [
        templatefile("${path.module}/helms/api-values.yaml.tftpl", {
          resource_prefix          = var.resource_prefix
          aws_account              = data.aws_caller_identity.current.account_id
          service_account          = "api"
          environment              = var.environment
          service_name             = var.service_name
          service_host_name        = "${var.service_name}.${var.environment}.${var.root_domain}"
          service_account          = "api"
          azs                      = ["a", "b", "c"]
          image_tag                = "${data.aws_caller_identity.current.account_id}.dkr.ecr.${var.region}.amazonaws.com/${var.resource_prefix}-ecr:${var.service_weather_image_tag}"
          cpu_requests             = var.cpu_requests
          mem_requests             = var.mem_requests
          cpu_limits               = var.cpu_limits
          mem_limits               = var.mem_limits
          open_weather_domain      = var.open_weather_domain
          open_weather_api_version = var.open_weather_api_version
          coord_longitude          = var.coord_longitude
          coord_latitude           = var.coord_latitude
          cognito_scope_key        = var.cognito_scope_key
          cognito_user_pool_id     = module.cognito-user-pool[0].id
          cognito_app_client_id    = module.cognito-user-pool[0].client_ids[0]
          region                   = var.region
        })
      ]
    }
  }
}


module "api-secrets" {
  count   = local.create ? 1 : 0
  source  = "terraform-aws-modules/secrets-manager/aws"
  version = "1.3.1"

  name                    = "${var.resource_prefix}-api-secrets"
  recovery_window_in_days = 30

  create_policy       = true
  block_public_policy = true
  policy_statements = {
    rw = {
      sid = "AllowAccountReadWrite"
      principals = [{
        type        = "AWS"
        identifiers = [
          "arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/${var.resource_prefix}-101digital-assignment-terraform-role",
          "arn:aws:iam::${data.aws_caller_identity.current.account_id}:root",
          ]
      }]
      actions = [
        "secretsmanager:DescribeSecret",
        "secretsmanager:GetSecretValue",
        "secretsmanager:PutSecretValue",
        "secretsmanager:UpdateSecretVersionStage",
      ]
      resources = ["*"]
    }
  }

  secret_string = jsonencode({
    open_weather_api_key = data.sops_file.secrets.data.open_weather_api_key
  })

  tags = try(merge(local.common_tags, {
    Name = "${var.resource_prefix}-api-secrets"
  }), local.common_tags)
}



resource "helm_release" "main" {
  for_each = {
    for k, v in local.helm_releases : k => v if local.create
  }

  name                = "${each.key}-release"
  repository          = try(each.value.repository, null)
  chart               = each.value.chart
  version             = each.value.version
  repository_username = data.aws_ecrpublic_authorization_token.token.user_name
  repository_password = data.aws_ecrpublic_authorization_token.token.password

  namespace        = try(each.value.namespace, "default")
  create_namespace = try(each.value.create_namespace, false)
  reset_values     = try(each.value.reset_values, false)

  lint = try(each.value.lint, false)

  values = try(each.value.value_files, [])

  dynamic "set" {
    for_each = {
      for k, v in try(each.value.overriden_values, []) : k => v if try(!v.is_sensitive, true) && try(!v.is_list, true)
    }
    iterator = set_default

    content {
      name  = set_default.value.name
      value = set_default.value.value
      type  = try(set_default.value.type, "string")
    }
  }

  dynamic "set_sensitive" {
    for_each = {
      for k, v in try(each.value.overriden_values, []) : k => v if try(v.is_sensitive, false)
    }

    content {
      name  = set_sensitive.value.name
      value = set_sensitive.value.value
      type  = try(set_sensitive.value.type, "string")
    }
  }

  dynamic "set_list" {
    for_each = {
      for k, v in try(each.value.overriden_values, []) : k => v if try(v.is_list, false)
    }

    content {
      name  = set_list.value.name
      value = set_list.value.value
    }
  }

  depends_on = [ 
    module.api_irsa,
    module.api-secrets
  ]
}