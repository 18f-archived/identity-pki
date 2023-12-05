provider "aws" {
  region              = "us-west-2"
  allowed_account_ids = ["894947205914"] # require login-sandbox
}

# Stub remote config
terraform {
  backend "s3" {
  }
}

variable "code_branch" {
  default = "main"
}

module "main" {
  source = "../module"

  code_branch         = var.code_branch
  image_build_nat_eip = "34.216.215.164" # TODO: make this programmable
}

module "vpc" {
  source = "../../modules/utility_vpc"

  account_name        = "sandbox"
  image_build_nat_eip = "34.216.215.191"
}

module "beta" {
  source = "../module_native"

  account_name          = "sandbox"
  env_name              = "beta"
  git2s3_bucket_name    = "codesync-identitybaseimage-outputbucket-rlnx3kivn8t8"
  identity_base_git_ref = "main"
  private_subnet_id     = module.vpc.private_subnet_id
  vpc_id                = module.vpc.vpc_id
}
