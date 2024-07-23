locals {
  region     = "us-west-2"
  account_id = "221972985980"
}

provider "aws" {
  region              = local.region
  allowed_account_ids = [local.account_id] # require login-logarchive-sandbox
}

# Stub remote config
terraform {
  backend "s3" {
  }
}

module "main" {
  source            = "../module"
  iam_account_alias = "login-logarchive-sandbox"

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
