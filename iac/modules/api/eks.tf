data "aws_caller_identity" "current" {}

locals {
  eks_managed_node_group_defaults = {
    ami_type               = "AL2_x86_64"
    disk_size              = 50
    instance_types         = try(var.managed_node_group_instance_types, ["t2.micro", "t2.small", "t2.medium"])
    vpc_security_group_ids = []
  }

  eks_clusters = {
    api = {
      name_suffix = "api"
      version     = try(var.eks_cluster_version, "1.31")
      cluster_addons = {
        coredns                = {}
        eks-pod-identity-agent = {}
        kube-proxy             = {}
        vpc-cni                = {}
      }
      access_entries = {
        terraform_admin = {
          kubernetes_groups = []
          principal_arn     = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:user/${var.resource_prefix}-101digital-assignment-${var.terraform_admin_user_name}"

          policy_associations = {
            example = {
              policy_arn = "arn:aws:eks::aws:cluster-access-policy/AmazonEKSClusterAdminPolicy"
              access_scope = {
                namespaces = [] # all namespace
                type       = "cluster"
              }
            }
          }
        }
      }
      eks_managed_node_groups = {
        default = {
          instance_types = try(var.default_managed_node_group_instance_type, ["t2.small"])
          min_size       = 1
          max_size       = 10
          desired_size   = 1
          capacity_type  = try(var.default_managed_node_group_capacity_type, "SPOT")
          labels = try(merge(local.common_tags, {
            manageNodeGroup = "true"
            purpose         = "default"
          }))
          taints = {}
          tags = {
            manageNodeGroup = "true"
          }
        }
      }
    }
  }

  irsas = {
    karpenter = {
      api = {
        cluster          = "api"
        node_group       = "default"
        role_name        = "karpenter_controller"
        namespaces       = ["karpenter"]
        service_accounts = ["karpenter-release"]
      }
    }
    api = {
      api = {
        cluster          = "api"
        node_group       = "default"
        role_name        = "api"
        namespaces       = ["default"]
        service_accounts = ["api"]
        policies = [
          {
            Version = "2012-10-17"
            Statement = [
              {
                Sid    = "ECRReadAccess"
                Effect = "Allow"
                Action = [
                  "ecr:GetDownloadUrlForLayer",
                  "ecr:BatchGetImage",
                  "ecr:BatchCheckLayerAvailability",
                  "ecr:DescribeRepositories",
                  "ecr:ListImages",
                  "ecr:DescribeImages"
                ]
                Resource = [
                  "arn:aws:ecr:${var.region}:${data.aws_caller_identity.current.account_id}:repository/${var.resource_prefix}-ecr"
                ]
              },
              {
                Sid    = "ECRAuthToken"
                Effect = "Allow"
                Action = [
                  "ecr:GetAuthorizationToken"
                ]
                Resource = ["*"]
              }
            ]
          },
          {
            Version = "2012-10-17"
            Statement = [
              {
                Sid    = "ECRWriteAccess"
                Effect = "Allow"
                Action = [
                  "ecr:GetDownloadUrlForLayer",
                  "ecr:BatchGetImage",
                  "ecr:BatchCheckLayerAvailability",
                  "ecr:PutImage",
                  "ecr:InitiateLayerUpload",
                  "ecr:UploadLayerPart",
                  "ecr:CompleteLayerUpload",
                  "ecr:DescribeRepositories",
                  "ecr:ListImages",
                  "ecr:DescribeImages"
                ]
                Resource = [
                  "arn:aws:ecr:${var.region}:${data.aws_caller_identity.current.account_id}:repository/${var.resource_prefix}-ecr"
                ]
              },
              {
                Sid    = "ECRAuthToken"
                Effect = "Allow"
                Action = [
                  "ecr:GetAuthorizationToken"
                ]
                Resource = ["*"]
              }
            ]
          }
        ]
      }
    }
    externaldns = {
      api = {
        cluster          = "api"
        node_group       = "default"
        role_name        = "external-dns"
        namespaces       = ["external-dns"]
        service_accounts = ["external-dns"]
      }
    }
    externalsecrets = {
      api = {
        cluster          = "api"
        node_group       = "default"
        role_name        = "external-secrest"
        namespaces       = ["external-secrets"]
        service_accounts = ["external-secrets"]
      }
    }
    certmanager = {
      api = {
        cluster          = "api"
        node_group       = "default"
        role_name        = "cert-manager"
        namespaces       = ["cert-manager"]
        service_accounts = ["cert-manager"]
      }
    }
  }
}

module "eks" {
  for_each = {
    for k, v in local.eks_clusters : k => v if local.create
  }
  source  = "terraform-aws-modules/eks/aws"
  version = "~> 20.0"

  cluster_name                             = "${var.resource_prefix}-${each.value.name_suffix}"
  cluster_version                          = each.value.version
  cluster_endpoint_private_access          = try(each.value.cluster_endpoint_private_access, true)
  cluster_endpoint_public_access           = try(each.value.cluster_endpoint_public_access, true)
  enable_cluster_creator_admin_permissions = try(each.value.enable_cluster_creator_admin_permissions, true)
  access_entries                           = try(each.value.access_entries, {})


  cluster_addons = try(each.value.cluster_addons, {})

  vpc_id     = module.vpc[each.key].vpc_id
  subnet_ids = module.vpc[each.key].private_subnets

  # EKS Managed Node Group(s)
  eks_managed_node_group_defaults = try(local.eks_managed_node_group_defaults, {})

  eks_managed_node_groups = try(each.value.eks_managed_node_groups, {})
}

module "karpenter" {
  for_each = {
    for k, v in try(local.irsas.karpenter, {}) : k => v if local.create
  }
  source  = "terraform-aws-modules/eks/aws//modules/karpenter"
  version = "20.26.1"

  cluster_name           = module.eks[each.value.cluster].cluster_name
  irsa_oidc_provider_arn = module.eks[each.value.cluster].oidc_provider_arn

  create_node_iam_role = false
  node_iam_role_arn    = module.eks[each.value.cluster].eks_managed_node_groups[each.value.node_group].iam_role_arn
  create_access_entry  = false

  create_iam_role = true
  enable_irsa     = true
  irsa_namespace_service_accounts = flatten([
    for namespace in each.value.namespaces : [
      for service_account in each.value.service_accounts : "${namespace}:${service_account}"
    ]
  ]) # namespace:service_account should match helm release sa name

  create_instance_profile = true

  tags = try(merge(local.common_tags, {
    manageKarpenter = "true"
    purpose         = "karpenter"
  }))
}

# This module will only create role but also attach policies based 
# irsa for externaDNS service account
module "externaldns_irsa" {
  for_each = {
    for k, v in try(local.irsas.externaldns, {}) : k => v if local.create
  }
  source  = "terraform-aws-modules/iam/aws//modules/iam-role-for-service-accounts-eks"
  version = "5.47.1"

  role_name                  = each.value.role_name
  attach_external_dns_policy = true # allow to attach external dns policy to role

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

# irsa for externaDNS service account
module "externalsecrets_irsa" {
  for_each = {
    for k, v in try(local.irsas.externalsecrets, {}) : k => v if local.create
  }
  source  = "terraform-aws-modules/iam/aws//modules/iam-role-for-service-accounts-eks"
  version = "5.47.1"

  role_name                      = each.value.role_name
  attach_external_secrets_policy = true # allow to attach external dns policy to role

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

# irsa for certmanager service account
module "certmanager_irsa" {
  for_each = {
    for k, v in try(local.irsas.certmanager, {}) : k => v if local.create
  }
  source  = "terraform-aws-modules/iam/aws//modules/iam-role-for-service-accounts-eks"
  version = "5.47.1"

  role_name                  = each.value.role_name
  attach_cert_manager_policy = true

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

