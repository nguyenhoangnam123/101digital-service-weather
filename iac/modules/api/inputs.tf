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

variable "service_name" {
  default = "service-weather"
}

variable "open_weather_domain" {
  default = "https://api.openweathermap.org/data"
}

variable "open_weather_api_version" {
  default = "2.5"
}

variable "coord_longitude" {
  default = "105.8342"
}

variable "coord_latitude" {
  default = "21.0278"
}

variable "cognito_scope_key" {
  default = "scope"
}

variable "mem_requests" {
  default = "128Mi"
}

variable "mem_limits" {
  default = "256Mi"
}

variable "cpu_requests" {
  default = "100m"
}

variable "cpu_limits" {
  default = "200m"
}
