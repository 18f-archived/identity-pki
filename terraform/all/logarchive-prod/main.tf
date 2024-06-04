provider "aws" {
  region              = "us-west-2"
  allowed_account_ids = ["429506220995"] # require login-logarchive-prod
}

# Stub remote config
terraform {
  backend "s3" {
  }
}

variable "splunk_oncall_cloudwatch_endpoint" {
  default = "UNSET"
}

variable "splunk_oncall_newrelic_endpoint" {
  default = "UNSET"
}

module "main" {
  source            = "../module"
  iam_account_alias = "login-logarchive-prod"

  splunk_oncall_cloudwatch_endpoint = var.splunk_oncall_cloudwatch_endpoint
  splunk_oncall_newrelic_endpoint   = var.splunk_oncall_newrelic_endpoint

  #limit_allowed_services = true  # uncomment to limit allowed services for all Roles

  # Restricted access - TODO: Add a role for historical search of data with
  # possible spilled PII
  account_roles_map = {
    iam_analytics_enabled      = false
    iam_auto_terraform_enabled = true
    iam_billing_enabled        = false
    iam_fraudops_enabled       = false
    iam_power_enabled          = false
    iam_readonly_enabled       = false
    iam_reports_enabled        = false
    iam_socadmin_enabled       = false
    iam_supporteng_enabled     = false
    iam_terraform_enabled      = true
  }
}
