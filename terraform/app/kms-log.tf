locals {
  kms_arns = concat([aws_iam_role.idp.arn],var.db_restore_role_arns)
}

module "kms_keymaker_uw2" {
  #source = "github.com/18F/identity-terraform//kms_log?ref=a58d0581b04b3562885dca32e07c0751e794db88"
  source = "../../../identity-terraform/kms_keymaker"

  env_name                   = var.env_name
  ec2_kms_arns               = local.kms_arns
}

module "kms_keymaker_ue1" {
  #source = "github.com/18F/identity-terraform//kms_log?ref=a58d0581b04b3562885dca32e07c0751e794db88"
  source = "../../../identity-terraform/kms_keymaker"
  providers = {
    aws = aws.use1
  }

  env_name                   = var.env_name
  ec2_kms_arns               = local.kms_arns
}

module "kms_logging" {
  #source = "github.com/18F/identity-terraform//kms_log?ref=a58d0581b04b3562885dca32e07c0751e794db88"
  source = "../../../identity-terraform/kms_log"

  env_name                   = var.env_name
  kmslogging_service_enabled = var.kmslogging_enabled
  sns_topic_dead_letter_arn  = var.slack_events_sns_hook_arn
  kinesis_shard_count        = var.kms_log_kinesis_shards
  ec2_kms_arns               = local.kms_arns
  
  keymaker_key_ids = [
    module.kms_keymaker_uw2.keymaker_arn,
    module.kms_keymaker_ue1.keymaker_arn
  ]
}
