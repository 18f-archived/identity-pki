provider "aws" {
  region              = "us-west-2"
  allowed_account_ids = ["340731855345"] # require login-master
  profile             = "login-master"

  #assume_role {
  #  role_arn     = "arn:aws:iam::ACCOUNT_ID:role/ROLE_NAME"
  #  session_name = "SESSION_NAME"
  #  external_id  = "EXTERNAL_ID"
  #}

  version = "~> 2.29"
}

# Stub remote config
terraform {
  backend "s3" {
  }
}

module "main" {
  source = "../module"

  region                          = "us-west-2"
  sandbox_account_id              = "894947205914"
  production_account_id           = "555546682965"
  sandbox_sms_account_id          = "035466892286"
  production_sms_account_id       = "472911866628"
  production_analytics_account_id = "461353137281"
  prod_secops_account_id          = "217680906704"
  dev_secops_account_id           = "138431511372"
  interviews_account_id           = "034795980528"
}

