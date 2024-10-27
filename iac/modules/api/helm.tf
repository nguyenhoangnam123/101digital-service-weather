
data "aws_ecrpublic_authorization_token" "token" {
}

locals {
  target_cluster = "api"
}

provider "kubernetes" {
  host                   = module.eks[local.target_cluster].cluster_endpoint
  cluster_ca_certificate = base64decode(module.eks[local.target_cluster].cluster_certificate_authority_data)

  exec {
    api_version = "client.authentication.k8s.io/v1beta1"
    command     = "aws"
    args        = ["eks", "get-token", "--cluster-name", module.eks[local.target_cluster].cluster_name]
  }
}

provider "helm" {
  kubernetes {
    host                   = module.eks[local.target_cluster].cluster_endpoint
    cluster_ca_certificate = base64decode(module.eks[local.target_cluster].cluster_certificate_authority_data)

    exec {
      api_version = "client.authentication.k8s.io/v1beta1"
      command     = "aws"
      args        = ["eks", "get-token", "--cluster-name", module.eks[local.target_cluster].cluster_name]
    }
  }
}

locals {
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
  }
}

resource "helm_release" "main" {
  for_each = {
    for k, v in local.helm_releases : k => v if local.create
  }

  name       = "${each.key}-release"
  repository = each.value.repository
  chart      = each.value.chart
  version    = each.value.version

  namespace        = try(each.value.namespace, "default")
  create_namespace = try(each.value.create_namespace, false)
  reset_values     = try(each.value.reset_values, false)

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
}