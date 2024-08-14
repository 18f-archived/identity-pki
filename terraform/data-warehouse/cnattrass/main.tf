locals {
  region     = "us-west-2"
  account_id = "487317109730"
}

provider "aws" {
  region              = local.region
  allowed_account_ids = [local.account_id] # require login-analytics-sandbox
}

data "aws_caller_identity" "current" {
}

terraform {
  backend "s3" {
  }
}

module "data_warehouse" {
  source                         = "../module"
  env_name                       = "cnattrass"
  bootstrap_main_git_ref_default = "stages/cnattrass"
  slack_events_sns_hook_arn      = "arn:aws:sns:us-west-2:${data.aws_caller_identity.current.account_id}:slack-otherevents"
  use_spot_instances             = 1
  autoscaling_schedule_name      = "dailyzero_normal"
}
