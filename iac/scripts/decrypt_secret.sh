#!/bin/bash

export AWS_REGION=us-east-1
export AWS_ACCOUNT=$1

if [ -z "$1" ]; then
    echo "Please set AWS environment"
    exit 1
fi
if [ -z "$2" ]; then
    echo "Profile is not set. Use default profile."
    export AWS_PROFILE="default"
else
    export AWS_PROFILE=$2
fi

export SOPS_KMS_ARN="arn:aws:kms:${AWS_REGION}:${AWS_ACCOUNT}:alias/sops-key"
