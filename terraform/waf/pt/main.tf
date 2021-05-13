provider "aws" {
  region              = "us-west-2"
  allowed_account_ids = ["894947205914"] # require login-sandbox
  profile             = "identitysandbox.gov"
}

# Stub remote config
terraform {
  backend "s3" {
  }
}

module "main" {
  source = "../module"

  env           = "pt"
  region        = "us-west-2"
  enforce       = true
  ip_block_list = ["34.216.215.141/32", "34.216.215.131/32", "34.216.215.136/32", "97.126.2.14/32"]
}
