include "root" {
  path   = find_in_parent_folders()
}

terraform {
  source = "../modules/api"

  before_hook "copy_vars" {
    commands = get_terraform_commands_that_need_vars()

    execute  = ["cp", "-r", "${dirname(find_in_parent_folders())}/helms/", "./helms"]
  }

  extra_arguments "common_vars" {
    commands = get_terraform_commands_that_need_vars()

    arguments = [
      "-var-file=${get_parent_terragrunt_dir()}/tfvars/common.tfvars",
    ]

    optional_var_files = [
      "${get_parent_terragrunt_dir()}/tfvars/dev.tfvars"
    ]
  }
}