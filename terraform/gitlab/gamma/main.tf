provider "aws" {
  region              = "us-west-2"
  allowed_account_ids = ["034795980528"] # require login-tooling-sandbox
}

# Stub remote config
terraform {
  backend "s3" {
  }
}

module "main" {
  source                         = "../module"
  bootstrap_main_git_ref_default = "stages/gitlabgamma"
  dr_region                      = "us-east-2"
  env_name                       = "gamma"
  env_type                       = "tooling-sandbox"
  region                         = "us-west-2"
  slack_events_sns_hook_arn      = "arn:aws:sns:us-west-2:034795980528:slack-otherevents"
  route53_id                     = "Z096400532ZFM348WWIAA"
  destination_artifact_accounts  = ["894947205914"] # login-sandbox
  accountids                     = ["894947205914", "034795980528", "217680906704"]
  asg_gitlab_test_runner_desired = 4
  use_waf_rules                  = false
  gitlab_runner_enabled          = true
  env_runner_gitlab_hostname     = "gitlab.login.gov"
  env_runner_config_bucket       = "login-gov-production-gitlabconfig-217680906704-us-west-2"
  gitlab_servicename             = "com.amazonaws.vpce.us-west-2.vpce-svc-0270024908d73003b"
  rds_engine_version             = "13.7"
}

output "env_name" {
  value = module.main.env_name
}

output "region" {
  value = module.main.region
}

output "latest_available_ami_id" {
  value = module.main.latest_available_ami_id
}

output "default_ami_id" {
  value = module.main.default_ami_id
}

output "ami_id_map" {
  value = module.main.ami_id_map
}
