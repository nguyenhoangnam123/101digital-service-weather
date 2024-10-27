## Howto:
## Initiate Terraform backend
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