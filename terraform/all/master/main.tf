provider "aws" {
  region              = "us-west-2"
  allowed_account_ids = ["340731855345"] # require login-master
}

# Stub remote config
terraform {
  backend "s3" {
  }
}

variable "splunk_oncall_cloudwatch_endpoint" {
  default = "UNSET"
}

module "main" {
  source            = "../module"
  iam_account_alias = "login-master"

  slack_events_sns_topic            = "slack-events"
  splunk_oncall_cloudwatch_endpoint = var.splunk_oncall_cloudwatch_endpoint

  #limit_allowed_services = true  # uncomment to limit allowed services for all Roles

  account_roles_map = {
    iam_power_enabled          = false
    iam_readonly_enabled       = false
    iam_socadmin_enabled       = true
    iam_terraform_enabled      = true
    iam_billing_enabled        = true
    iam_auto_terraform_enabled = false
  }

  account_cloudwatch_log_groups = [
    "/var/log/messages"
  ]
}

module "config_password_rotation" {
  source = "../../modules/config_iam_password_rotation"

  config_password_rotation_name = module.main.config_password_rotation_name
  region                        = module.main.region
  config_password_rotation_code = "../../modules/config_iam_password_rotation/${module.main.config_password_rotation_code}"
}
