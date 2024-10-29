#!/bin/bash

wget https://github.com/gruntwork-io/terragrunt/releases/download/v0.68.4/terragrunt_linux_${1}

sudo mv terragrunt_linux_${1} /usr/local/bin/terragrunt && chmod a+x /usr/local/bin/terragrunt

echo "alias tg=terragrunt" >> ~/.bashrc
source ~/.bashrc