provider "aws" {
  region              = "us-west-2"
  allowed_account_ids = ["217680906704"] # require login-tooling-prod
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

  trigger_source      = "CloudWatch"
  code_branch         = var.code_branch
  image_build_nat_eip = "35.89.44.224"
}

module "vpc" {
  source = "../../modules/utility_vpc"

  account_name        = "tooling-prod"
  image_build_nat_eip = "35.89.44.230"
}

module "tooling-prod" {
  source = "../module_native"

  base_codebuild_name  = "login-image-base"
  rails_codebuild_name = "login-image-rails"
  base_pipeline_name   = "CodePipeline-ImageBaseRole-CodePipeline-1NLQQOIIUS8DG"
  rails_pipeline_name  = "CodePipeline-ImageRailsRole-CodePipeline-5KBZJ4N4QY7X"

  account_name          = "tooling-prod"
  env_name              = "tooling-prod"
  identity_base_git_ref = "main"
  private_subnet_id     = module.vpc.private_subnet_id
  vpc_id                = module.vpc.vpc_id
}
