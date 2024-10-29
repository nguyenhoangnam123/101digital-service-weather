## Howto:

### Backend configurations

- Implement FastAPI with Annotation to protect API with AWS Cognito as Identity Provider
- Backend structure

```
src
├── __init__.py
├── __pycache__
│   ├── __init__.cpython-311.pyc
│   └── app.cpython-311.pyc
├── api
│   ├── __init__.py
│   ├── __pycache__
│   │   └── __init__.cpython-311.pyc
│   ├── middleware
│   │   ├── __init__.py
│   │   └── oauth2.py
│   ├── schema
│   │   ├── __init__.py
│   │   ├── __pycache__
│   │   │   ├── __init__.cpython-311.pyc
│   │   │   └── open_weather_rest.cpython-311.pyc
│   │   └── open_weather_rest.py
│   └── v1
│       ├── __init__.py
│       ├── __pycache__
│       │   └── __init__.cpython-311.pyc
│       └── routers
│           ├── __init__.py
│           ├── __pycache__
│           │   ├── __init__.cpython-311.pyc
│           │   └── weather.cpython-311.pyc
│           └── weather.py
├── app.py
└── settings
    ├── __init__.py
    ├── __pycache__
    │   ├── __init__.cpython-311.pyc
    │   └── config.cpython-311.pyc
    └── config.py
poetry.lock
pyproject.toml
```

- Control Environment variables by Pydantic

  - Configuration for `service-weather`:

```.env
OPEN_WEATHER_DOMAIN=https://api.openweathermap.org/data
OPEN_WEATHER_API_VERSION=2.5
OPEN_WEATHER_API_KEY=
COORD_LONGITUDE=105.8342
COORD_LATITUDE=21.0278

AWS_DEFAULT_REGION=
COGNITO_USER_POOL_ID=
COGNITO_APP_CLIENT_ID=
COGNITO_SCOPE_KEY=scope
```

- Local environment: Use docker-compose.yaml, .env.local and Pydantic settings

```docker-compose.yaml
version: "3.9"
services:
  service-weather:
    build:
      context: .
      dockerfile: Dockerfile
    image: service-weather
    ports:
      - "8000:8080"
    command: poetry run uvicorn src.app:app --host 0.0.0.0 --port 8080 --reload
    env_file:
      - .env
      - .env.local # Set environment variables for Pydantic settings
```

- EKS environment: Use Terraform to full fill container env for non-sensitive data. For sensitive data (`OPEN_WEATHER_API_KEY`), we use `sops` to GitOps secrets, AWS secret manager to remotely store `OPEN_WEATHER_API_KEY` and `external-secrets` to manage secret lifecycle
- How protection works under the hood

```python
# consider src/api/v1/routes/weather.py

@routers.get("/get-today-weather", dependencies=[Depends(auth.scope(["test/weatherforcastapi"]))])
async def get_today_weather():
  """
  Endpoint /api/v1/get-today-weather" will be authenticated by client_credentials authentication and check scope for authorization
  """
  response = requests.get(f"{OPEN_WEATHER_REST.get_weather_url()}", headers={"Content-Type": "application/json"})
  logger.info(f"response is {response.json()}, status is {response.status_code}")
  return JSONResponse(status_code=response.status_code, content=response.json())

# consider src.app.py:register_routes
def register_routes(service_weather_app):
    """
    Register application routes and health check route for K8s livenessProbe and readinessProbe
    """
    service_weather_app.include_router(routers)
    @service_weather_app.get("/health")
    async def health_check():
        return JSONResponse(status_code=200, content={"status": "ok"})
```

## Terragrunt structure

### Architecture design record:

- For DRY terraform code across environments (config, runtime environment, etc)

### Inititate backend for certain environment

- Prerquesite: Can assume role which has `AdministrativeAccess` policy
- We will initiate following resources beforing actual running Terragrunt

```CloudFormation.yaml
# Consider ./iac/dev/cloudformation.yaml

# S3 Bucket for Terraform State
TerraformStateBucket:
  Type: "AWS::S3::Bucket"

# S3 Bucket Policy
TerraformStateBucketPolicy:
  Type: "AWS::S3::BucketPolicy"

# DynamoDB Table for State Locking
TerraformLockTable:
  Type: "AWS::DynamoDB::Table"

# IAM Role for Terraform. Will be grantd access scope for EKS cluster
TerraformRole:
  Type: "AWS::IAM::Role"

# OIDC auth to allow Github repository consume AWS role
GitHubOIDCProvider:
  Type: AWS::IAM::OIDCProvider

# KMS key to allow sops CLI to encrypt/decrypt ./iac/secrets/secrets.*.yaml (GitOps secret)
SOPSKMSKey:
  Type: AWS::KMS::Key

# KMS key sops alias
SOPSKMSKeyAlias:
  Type: AWS::KMS::Alias
```

- How to run cloudformation from scripts

```bash
# navigate to environment. Eg: dev
cd ./iac/scripts

# Please update target environment configuration inside init_terraform_backend.sh
# export AWS_PROFILE="mightystingbee-root"
# export RESOURCE_PREFIX="mightystingbee-101digital-assignment"

chmod u+x ./init_terraform_backend.sh

# check cf stack status
 aws cloudformation describe-stacks \
  --stack-name terraform-backend \
  --query 'Stacks[0].StackStatus'
```

## Terragrunt plan

- Before running terragrunt againts any `./iac/<dev|prod>` root foldder. Please concern about
  - `./iac/tfvars/<env>.tfvars`

```terraform.tfvars
# ./iac/tfvars/common.tfvars
root_domain="mightybee.dev"
resource_prefix="mightystingbee"
terraform_admin_user_name="terraform-admin"
# EKS
eks_cluster_version="1.31"
# service-weather
service_name="service-weather"
open_weather_domain="https://api.openweathermap.org/data"
open_weather_api_version="2.5"
coord_longitude="105.8342"
coord_latitude="21.0278"
cognito_scope_key="scope"
service_weather_image_tag="latest"

# ./iac/tfvars/prod.tfvars
environment="prod"
region="us-east-1"
# eks node group tier
managed_node_group_instance_types=["c3.large", "c4.large", "c5.large"]
default_managed_node_group_instance_type=["c3.large"]
default_managed_node_group_capacity_type="ON_DEMAND"
# service-weather resources
mem_requests="256Mi"
mem_limits="1Mi"
cpu_requests="1"
cpu_limits="1"
```

- Create `OPEN_WEATHER_API_KEY` secret from sops, which will be used to create AWS secret-manager key and managed external-secrets
  - Fullfill value for `open_weather_api_key` in `./iac/sops/secrets.sample.yaml`
  - Run command to create encrypted file. Eg: create encrypted file for prod
  ```
  export SOPS_KMS_ARN=
  sops -e -k $SOPS_KMS_ARN secrets.sample.yaml > secrets.prod.encrypted.yaml
  ```
  - This file will be read by Terraform datasource
  ```terraform.tf
  data "sops_file" "secrets" {
    source_file = "${path.module}/secrets/secrets.${var.environment}. encrypted.yaml"
  }
  ```

### Terragrunt resources

- Terragrunt will consolidates following resources in runtime
  - Checkout version of `./iac/module/api` for root module `./iac/<env>`
  - Copy `./iac/helms/` to `./iac/<env>/helms`
  - Takes `./iac/tfvars/<env>.tfvars` and `./iac/tfvars/common.tfvars` as prior variable values
  - Networking: Including VPCs, subnets, route tables, NATGW, security groups
  - EKS: EKS cluster, EKS managed node group (ASG), VPC CNI, CoreDNS (as minimum setup), OIDC Identity Provider for EKS cluster, IRSA for K8s sa act as AWS role
  - Helm: Including external-dns to automatically provision record set against certain Route53 Zones, Karpenter for cluster autoscaling, Ingress Nginx Controller for auto provision ALB based on Ingress, and finally our main `service-weather` which is a local self-managed Helm chart `./iac/helms/api/`

### Walkthrough service-weather Helm chart

- Deployment:
  - Service account has IRSA against `ECR, secret-manager`

```terraform.tf
# irsa for api service account
module "api_irsa" {
  for_each = {
    for k, v in try(local.irsas.api, {}) : k => v if local.create
  }
  source  = "terraform-aws-modules/iam/aws//modules/iam-role-for-service-accounts-eks"
  version = "5.47.1"

  role_name                      = each.value.role_name
  attach_external_secrets_policy = true # module support external_secrets policy attachment

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
```

- Deployment utilized with `NodeAffinity` and `topologySpreadConstraints` for pod scheduling evenly across zones - HA enhancement
- API config via environment variables and mount from external-secrets resources

```yaml
...
env:
  - name: OPEN_WEATHER_API_KEY
    valueFrom:
      secretKeyRef:
          name: {{ .Values.global.service_name }}-api-secrets
          key: {{ .Values.global.open_weather_api_key }}
  {{- with (index .Values.deployment.containers 0) }}
  {{- toYaml .extraEnvs | nindent 12 }}
  {{- end }}
...
```

## How-to test locally

After creating all infrastructure, we can test API locally by docker-compose.yaml and Postman

- Step 1: Create OpenWeather API Key from: https://openweathermap.org/api
- Step 2: Restore Postman workspace from file `service-weather.postman_collection.json`
  ![Restore workspace with collections dev/prod](/images/postman_dev_environment.png)
  ![Claim JWT access token](/images/postman_claim_token_collection.png)
  ![Use JWT access token](/images/postman_use_token.png)
- Step 2: Create file `.env.local` from `.env` and full-fill all missing value in `.env.local`
  - `OPEN_WEATHER_API_KEY`
  - `COGNITO_USER_POOL_ID`
  - `COGNITO_APP_CLIENT_ID`
- Step 3: Run docker compose by this command to provision container, tunneling port 8000 from host to container port 8080

```sh
docker compose -f docker-compose.ci.yaml up --build -d
```

![Docker compose service-weather container](/images/docker_compose_container.png)

- Step 4: Navigate to address: http://localhost:8000/docs
  ![Service-weather docs](/images/service_weather_docs.png)

- Step 5: Test API authentication
  ![Service-weather submit JWT](/images/service_weather_submit_token.png)
  ![Service-weather authorization with JWT](/images/service_weather_authorization.png)

## References

### For OAuth2 Authentication via Cognito user pool and client_credentials grant_type

- [Cognito Oauth2 endpoint](https://docs.aws.amazon.com/cognito/latest/developerguide/token-endpoint.html)
- [Validate Cognito OAuth2 JWT token](https://docs.aws.amazon.com/cognito/latest/developerguide/amazon-cognito-user-pools-using-tokens-verifying-a-jwt.html)
