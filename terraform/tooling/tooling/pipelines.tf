# Set up global config for codebuild/pipeline
module "main" {
  source = "../module"
  region = "us-west-2"
}

# # deploy the master/global target to the login-master account
# module "masterglobal" {
#   region = "us-west-2"
#   source = "../module-pipeline"

#   # This is the dir under the terraform dir to tf in identity-devops
#   tf_dir = "master/global"
#   # This is the gitref to check out in identity-devops
#   gitref = "stages/prodinfra"
#   # This is the account to deploy tf_dir into
#   account = "340731855345"

#   # pass in global config using module composition (https://www.terraform.io/docs/modules/composition.html)
#   auto_tf_vpc_id = module.main.auto_tf_vpc_id
#   auto_tf_subnet_id = module.main.auto_tf_subnet_id
#   auto_tf_role_arn = module.main.auto_tf_role_arn
#   auto_tf_sg_id = module.main.auto_tf_sg_id
#   auto_tf_bucket_id = module.main.auto_tf_bucket_id
#   auto_tf_pipeline_role_arn = module.main.auto_tf_pipeline_role_arn
# }


# deploy the all/tooling target to the tooling account on the main branch
module "alltooling" {
  region = "us-west-2"
  source = "../module-pipeline"

  # This is the dir under the terraform dir to tf in identity-devops
  tf_dir = "all/tooling"
  # This is the gitref to check out in identity-devops
  gitref = "main"
  # This is the account to deploy tf_dir into
  account = "034795980528"

  # pass in global config using module composition (https://www.terraform.io/docs/modules/composition.html)
  auto_tf_vpc_id            = module.main.auto_tf_vpc_id
  auto_tf_subnet_id         = module.main.auto_tf_subnet_id
  auto_tf_role_arn          = module.main.auto_tf_role_arn
  auto_tf_sg_id             = module.main.auto_tf_sg_id
  auto_tf_bucket_id         = module.main.auto_tf_bucket_id
  auto_tf_pipeline_role_arn = module.main.auto_tf_pipeline_role_arn
}


# deploy the tooling/tooling target to the tooling account on the main branch
module "toolingtooling" {
  region = "us-west-2"
  source = "../module-pipeline"

  # This is the dir under the terraform dir to tf in identity-devops
  tf_dir = "tooling/tooling"
  # This is the gitref to check out in identity-devops
  gitref = "main"
  # This is the account to deploy tf_dir into
  account = "034795980528"

  # pass in global config using module composition (https://www.terraform.io/docs/modules/composition.html)
  auto_tf_vpc_id            = module.main.auto_tf_vpc_id
  auto_tf_subnet_id         = module.main.auto_tf_subnet_id
  auto_tf_role_arn          = module.main.auto_tf_role_arn
  auto_tf_sg_id             = module.main.auto_tf_sg_id
  auto_tf_bucket_id         = module.main.auto_tf_bucket_id
  auto_tf_pipeline_role_arn = module.main.auto_tf_pipeline_role_arn
}

# deploy the all/sandbox target to the sandbox account on the main branch
module "allsandbox" {
  region = "us-west-2"
  source = "../module-pipeline"

  # This is the dir under the terraform dir to tf in identity-devops
  tf_dir = "all/sandbox"
  # This is the gitref to check out in identity-devops
  gitref = "main"
  # This is the account to deploy tf_dir into
  account = "894947205914"

  # pass in global config using module composition (https://www.terraform.io/docs/modules/composition.html)
  auto_tf_vpc_id            = module.main.auto_tf_vpc_id
  auto_tf_subnet_id         = module.main.auto_tf_subnet_id
  auto_tf_role_arn          = module.main.auto_tf_role_arn
  auto_tf_sg_id             = module.main.auto_tf_sg_id
  auto_tf_bucket_id         = module.main.auto_tf_bucket_id
  auto_tf_pipeline_role_arn = module.main.auto_tf_pipeline_role_arn
}

# deploy the all/alpha target to the alpha account on the stages/alphainfra branch
module "allalpha" {
  region = "us-west-2"
  source = "../module-pipeline"

  # This is the dir under the terraform dir to tf in identity-devops
  tf_dir = "all/alpha"
  # This is the gitref to check out in identity-devops
  gitref = "stages/alphainfra"
  # This is the account to deploy tf_dir into
  account = "917793222841"

  # pass in global config using module composition (https://www.terraform.io/docs/modules/composition.html)
  auto_tf_vpc_id            = module.main.auto_tf_vpc_id
  auto_tf_subnet_id         = module.main.auto_tf_subnet_id
  auto_tf_role_arn          = module.main.auto_tf_role_arn
  auto_tf_sg_id             = module.main.auto_tf_sg_id
  auto_tf_bucket_id         = module.main.auto_tf_bucket_id
  auto_tf_pipeline_role_arn = module.main.auto_tf_pipeline_role_arn
}

# # deploy the all/secopsdev target to the secopsdev account on the main branch
# module "allsecopsdev" {
#   region = "us-west-2"
#   source = "../module-pipeline"

#   # This is the dir under the terraform dir to tf in identity-devops
#   tf_dir = "all/secopsdev"
#   # This is the gitref to check out in identity-devops
#   gitref = "main"
#   # This is the account to deploy tf_dir into
#   account = "138431511372"

#   # pass in global config using module composition (https://www.terraform.io/docs/modules/composition.html)
#   auto_tf_vpc_id            = module.main.auto_tf_vpc_id
#   auto_tf_subnet_id         = module.main.auto_tf_subnet_id
#   auto_tf_role_arn          = module.main.auto_tf_role_arn
#   auto_tf_sg_id             = module.main.auto_tf_sg_id
#   auto_tf_bucket_id         = module.main.auto_tf_bucket_id
#   auto_tf_pipeline_role_arn = module.main.auto_tf_pipeline_role_arn
# }

# deploy the all/sms-sandbox target to the sms-sandbox account on the main branch
module "allsms-sandbox" {
  region = "us-west-2"
  source = "../module-pipeline"

  # This is the dir under the terraform dir to tf in identity-devops
  tf_dir = "all/sms-sandbox"
  # This is the gitref to check out in identity-devops
  gitref = "main"
  # This is the account to deploy tf_dir into
  account = "035466892286"

  # pass in global config using module composition (https://www.terraform.io/docs/modules/composition.html)
  auto_tf_vpc_id            = module.main.auto_tf_vpc_id
  auto_tf_subnet_id         = module.main.auto_tf_subnet_id
  auto_tf_role_arn          = module.main.auto_tf_role_arn
  auto_tf_sg_id             = module.main.auto_tf_sg_id
  auto_tf_bucket_id         = module.main.auto_tf_bucket_id
  auto_tf_pipeline_role_arn = module.main.auto_tf_pipeline_role_arn
}

# deploy the sms/sandbox target to the sms-sandbox account on the main branch
module "smssandbox" {
  region = "us-west-2"
  source = "../module-pipeline"

  # This is the dir under the terraform dir to tf in identity-devops
  tf_dir = "sms/sandbox"
  # This is the gitref to check out in identity-devops
  gitref = "main"
  # This is the account to deploy tf_dir into
  account = "035466892286"

  # pass in global config using module composition (https://www.terraform.io/docs/modules/composition.html)
  auto_tf_vpc_id            = module.main.auto_tf_vpc_id
  auto_tf_subnet_id         = module.main.auto_tf_subnet_id
  auto_tf_role_arn          = module.main.auto_tf_role_arn
  auto_tf_sg_id             = module.main.auto_tf_sg_id
  auto_tf_bucket_id         = module.main.auto_tf_bucket_id
  auto_tf_pipeline_role_arn = module.main.auto_tf_pipeline_role_arn
}

# deploy the sms/sandbox-east target to the sms-sandbox account on the main branch
module "smssandboxeast" {
  region = "us-west-2"
  source = "../module-pipeline"

  # This is the dir under the terraform dir to tf in identity-devops
  tf_dir = "sms/sandbox-east"
  # This is the gitref to check out in identity-devops
  gitref = "main"
  # This is the account to deploy tf_dir into
  account = "035466892286"

  # pass in global config using module composition (https://www.terraform.io/docs/modules/composition.html)
  auto_tf_vpc_id            = module.main.auto_tf_vpc_id
  auto_tf_subnet_id         = module.main.auto_tf_subnet_id
  auto_tf_role_arn          = module.main.auto_tf_role_arn
  auto_tf_sg_id             = module.main.auto_tf_sg_id
  auto_tf_bucket_id         = module.main.auto_tf_bucket_id
  auto_tf_pipeline_role_arn = module.main.auto_tf_pipeline_role_arn
}

# deploy the tspencer environment to the sandbox account on the stages/tspencer branch!
module "tspencer" {
  region = "us-west-2"
  source = "../module-pipeline"

  # This is the dir under the terraform dir to tf in identity-devops
  tf_dir = "app"
  # This is the environment to deploy to
  env_name = "tspencer"
  # This is the gitref to check out in identity-devops
  gitref = "stages/tspencer"
  # This is the account to deploy tf_dir into
  account = "894947205914"

  # pass in global config using module composition (https://www.terraform.io/docs/modules/composition.html)
  auto_tf_vpc_id            = module.main.auto_tf_vpc_id
  auto_tf_subnet_id         = module.main.auto_tf_subnet_id
  auto_tf_role_arn          = module.main.auto_tf_role_arn
  auto_tf_sg_id             = module.main.auto_tf_sg_id
  auto_tf_bucket_id         = module.main.auto_tf_bucket_id
  auto_tf_pipeline_role_arn = module.main.auto_tf_pipeline_role_arn
}

# deploy the pt environment to the sandbox account on the stages/pt branch!
module "pt" {
  region = "us-west-2"
  source = "../module-pipeline"

  # This is the dir under the terraform dir to tf in identity-devops
  tf_dir = "app"
  # This is the environment to deploy to
  env_name = "pt"
  # This is the gitref to check out in identity-devops
  gitref = "stages/pt"
  # This is the account to deploy tf_dir into
  account = "894947205914"

  # pass in global config using module composition (https://www.terraform.io/docs/modules/composition.html)
  auto_tf_vpc_id            = module.main.auto_tf_vpc_id
  auto_tf_subnet_id         = module.main.auto_tf_subnet_id
  auto_tf_role_arn          = module.main.auto_tf_role_arn
  auto_tf_sg_id             = module.main.auto_tf_sg_id
  auto_tf_bucket_id         = module.main.auto_tf_bucket_id
  auto_tf_pipeline_role_arn = module.main.auto_tf_pipeline_role_arn
}

# deploy the pt2 environment to the sandbox account on the stages/pt2 branch!
module "pt2" {
  region = "us-west-2"
  source = "../module-pipeline"

  # This is the dir under the terraform dir to tf in identity-devops
  tf_dir = "app"
  # This is the environment to deploy to
  env_name = "pt2"
  # This is the gitref to check out in identity-devops
  gitref = "stages/pt2"
  # This is the account to deploy tf_dir into
  account = "894947205914"

  # pass in global config using module composition (https://www.terraform.io/docs/modules/composition.html)
  auto_tf_vpc_id            = module.main.auto_tf_vpc_id
  auto_tf_subnet_id         = module.main.auto_tf_subnet_id
  auto_tf_role_arn          = module.main.auto_tf_role_arn
  auto_tf_sg_id             = module.main.auto_tf_sg_id
  auto_tf_bucket_id         = module.main.auto_tf_bucket_id
  auto_tf_pipeline_role_arn = module.main.auto_tf_pipeline_role_arn
}

# Deploy sandboxes using a standard pattern
module "app_sandboxes" {
  for_each = yamldecode(file("./app_sandboxes.yml"))

  region = "us-west-2"
  source = "../module-pipeline"

  # This is the dir under the terraform dir to tf in identity-devops
  tf_dir = "app"
  # This is the environment to deploy to
  env_name = each.key
  # This is the gitref to check out in identity-devops
  gitref = each.value
  # This is the account to deploy tf_dir into
  account = "894947205914"

  # pass in global config using module composition (https://www.terraform.io/docs/modules/composition.html)
  auto_tf_vpc_id            = module.main.auto_tf_vpc_id
  auto_tf_subnet_id         = module.main.auto_tf_subnet_id
  auto_tf_role_arn          = module.main.auto_tf_role_arn
  auto_tf_sg_id             = module.main.auto_tf_sg_id
  auto_tf_bucket_id         = module.main.auto_tf_bucket_id
  auto_tf_pipeline_role_arn = module.main.auto_tf_pipeline_role_arn
}

# Deploy WAFv2 using a standard pattern
module "waf_sandboxes" {
  for_each = yamldecode(file("./waf_sandboxes.yml"))

  region = "us-west-2"
  source = "../module-pipeline"

  # This is the dir under the terraform dir to tf in identity-devops
  tf_dir = "waf/${each.key}"
  # This is the gitref to check out in identity-devops
  gitref = each.value
  # This is the account to deploy tf_dir into
  account = "894947205914"

  # pass in global config using module composition (https://www.terraform.io/docs/modules/composition.html)
  auto_tf_vpc_id            = module.main.auto_tf_vpc_id
  auto_tf_subnet_id         = module.main.auto_tf_subnet_id
  auto_tf_role_arn          = module.main.auto_tf_role_arn
  auto_tf_sg_id             = module.main.auto_tf_sg_id
  auto_tf_bucket_id         = module.main.auto_tf_bucket_id
  auto_tf_pipeline_role_arn = module.main.auto_tf_pipeline_role_arn
}

# deploy the gitlabtest gitlab cluster to the tooling account on the main branch!
module "gitlabtest" {
  region = "us-west-2"
  source = "../module-gitlabpipeline"

  # This is the environment to deploy to
  cluster_name = "gitlabtest"
  # this is the dns domain that the cluster is put under
  domain = "gitlab.identitysandbox.gov"
  # This is the gitref to check out in identity-devops
  gitref = "tspencer/autotfgitlab"
  # This is the account to deploy this gitlab instance into
  account = "034795980528"

  # pass in global config using module composition (https://www.terraform.io/docs/modules/composition.html)
  auto_tf_vpc_id            = module.main.auto_tf_vpc_id
  auto_tf_subnet_id         = module.main.auto_tf_subnet_id
  auto_tf_role_arn          = module.main.auto_tf_role_arn
  auto_tf_sg_id             = module.main.auto_tf_sg_id
  auto_tf_bucket_id         = module.main.auto_tf_bucket_id
  auto_tf_pipeline_role_arn = module.main.auto_tf_pipeline_role_arn
}
