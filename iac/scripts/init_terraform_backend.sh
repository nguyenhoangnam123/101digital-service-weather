#!/bin/bash

#export AWS_PROFILE=""
#export RESOURCE_PREFIX=""

# Eg:
 export AWS_PROFILE="mightystingbee-root"
 export RESOURCE_PREFIX="mightystingbee-101digital-assignment"

if [ -z "$1" ]; then
  echo "Please set AWS environment"
  exit 1
elif [ -z "${AWS_PROFILE}" ]; then
  echo "Please set AWS_PROFILE"
  exit 1
elif [ -z "${RESOURCE_PREFIX}" ]; then
  echo "Please set RESOURCE_PREFIX"
  exit 1
fi

aws cloudformation create-stack \
  --stack-name terraform-backend \
  --template-body file://../$1/cloudformation.yaml \
  --parameters ParameterKey=ResourcePrefix,ParameterValue="${RESOURCE_PREFIX}" \
  --capabilities CAPABILITY_NAMED_IAM


  aws cloudformation create-change-set \
  --stack-name terraform-backend \
  --change-set-name add-terraform-admin-user \
  --template-body file://cloudformation.yaml \
  --capabilities CAPABILITY_NAMED_IAM