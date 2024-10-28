locals {
  cognito_resource_servers = [
    {
      name       = "${var.resource_prefix}-resource-server"
      identifier = "https://auth.${var.environment}.${var.root_domain}"
      scope = [
        { scope_name = "get:today-weather", scope_description = "Get today weather" },
      ]
    }
  ]
}
module "cognito-user-pool" {
  count   = local.create ? 1 : 0
  source  = "lgallard/cognito-user-pool/aws"
  version = "0.32.0"

  user_pool_name           = "${var.resource_prefix}-cognito-user-pool"
  alias_attributes         = ["email"]
  auto_verified_attributes = ["email"]

  deletion_protection = "ACTIVE"

  #  clients
  clients = [
    {
      name                         = "${var.resource_prefix}-weather-service"
      allowed_oauth_flows          = ["client_credentials"]
      explicit_auth_flows          = ["ALLOW_ADMIN_USER_PASSWORD_AUTH", "ALLOW_REFRESH_TOKEN_AUTH", "ALLOW_USER_PASSWORD_AUTH", "ALLOW_USER_SRP_AUTH"]
      callback_urls                = ["https://example.com"] # required
      supported_identity_providers = ["COGNITO"]
      allowed_oauth_scopes = flatten([
        for rs in local.cognito_resource_servers : [
          for scope in rs.scope : [
            "${rs.identifier}/${scope.scope_name}" # custom scopes can be added by identifier/scope_name
          ]
        ]
      ])
      generate_secret = true
      read_attributes = ["email"]
    }
  ]

  # domain
  domain = "${var.resource_prefix}-${var.environment}-auth"

  #   rsource servers
  resource_servers = local.cognito_resource_servers

  recovery_mechanisms = [
    {
      name     = "verified_email"
      priority = 1
    },
    {
      name     = "verified_phone_number"
      priority = 2
    }
  ]

  tags = try(merge(local.common_tags, {
    manageCognito = "true"
  }))
}