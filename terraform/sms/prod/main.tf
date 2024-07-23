locals {
  region     = "us-west-2"
  account_id = "472911866628"
}

provider "aws" {
  region              = local.region
  allowed_account_ids = [local.account_id] # require login-sms-prod
}

# Stub remote config
terraform {
  backend "s3" {
  }
}

module "account_pinpoint" {
  # These are provisoned per-AWS account. This module should only be used
  # in the us-west-2 environment.
  source = "../../modules/account_pinpoint/"

  main_account_id = "555546682965"
}

module "main" {
  source = "../module"

  env                      = "prod"
  region                   = "us-west-2"
  pinpoint_app_name        = "login.gov"
  state_lock_table         = "terraform_locks"
  sns_topic_alert_critical = "slack-alarms" # page
  sns_topic_alert_warning  = "slack-events"
  pinpoint_spend_limit     = 210000 # USD monthly
  sms_support_api_endpoint = "https://secure.login.gov/api/country-support.json"

  sms_unexpected_individual_country_alarm_thresholds = {
    "DE" = 200,
    "GB" = 200,
    "CO" = 300
  }
}

output "pinpoint_app_id" {
  value = module.main.pinpoint_app_id
}

output "pinpoint_idp_role_arn" {
  value = module.account_pinpoint.pinpoint_idp_role_arn
}

