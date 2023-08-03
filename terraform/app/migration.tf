# Very similar to terraform/app/idp.tf

resource "aws_iam_instance_profile" "migration" {
  name = "${var.env_name}_migration_instance_profile"
  role = module.application_iam_roles.migration_iam_role_name
}

module "migration_usw2" {
  depends_on = [
    module.outboundproxy_uw2.proxy_asg_name,
    aws_cloudwatch_log_group.nginx_access_log
  ]
  source                           = "../modules/migration_hosts"
  ami_id_map                       = var.ami_id_map
  asg_migration_min                = var.asg_migration_min
  asg_migration_desired            = var.asg_migration_desired
  asg_migration_max                = var.asg_migration_max
  asg_enabled_metrics              = var.asg_enabled_metrics
  autoscaling_time_zone            = var.autoscaling_time_zone
  autoscaling_schedule_name        = var.autoscaling_schedule_name
  base_security_group_id           = module.network_usw2.base_id
  bootstrap_private_git_clone_url  = var.bootstrap_private_git_clone_url
  bootstrap_private_git_ref        = var.bootstrap_private_git_ref
  bootstrap_private_s3_ssh_key_url = var.bootstrap_private_s3_ssh_key_url
  bootstrap_main_git_clone_url     = var.bootstrap_main_git_clone_url
  bootstrap_main_git_ref_default   = var.bootstrap_main_git_ref_default
  bootstrap_main_git_ref_map       = var.bootstrap_main_git_ref_map
  bootstrap_main_s3_ssh_key_url    = var.bootstrap_main_s3_ssh_key_url
  chef_download_url                = var.chef_download_url
  chef_download_sha256             = var.chef_download_sha256
  rails_ami_id                     = local.account_rails_ami_id
  env_name                         = var.env_name
  fisma_tag                        = var.fisma_tag
  instance_type_migration          = var.instance_type_migration
  migration_instance_profile       = aws_iam_instance_profile.migration.name
  migration_rotation_schedules     = local.migration_rotation_schedules
  migration_subnet_ids             = [for subnet in module.network_usw2.app_subnet : subnet.id]
  migration_security_group_id      = module.network_usw2.migration_sg_id
  no_proxy_hosts                   = var.no_proxy_hosts
  proxy_enabled_roles              = var.proxy_enabled_roles
  proxy_port                       = var.proxy_port
  proxy_server                     = var.proxy_server
  root_domain                      = var.root_domain
  s3_secrets_bucket_name           = data.aws_s3_bucket.secrets.bucket
  slack_events_sns_hook_arn        = var.slack_events_sns_hook_arn
}

##### moved blocks, remove once state moves are complete

moved {
  from = module.migration_usw2.aws_security_group.migration
  to   = module.network_usw2.aws_security_group.migration
}

moved {
  from = aws_autoscaling_group.migration
  to   = module.migration_usw2.aws_autoscaling_group.migration
}

moved {
  from = module.migration_lifecycle_hooks
  to   = module.migration_usw2.module.migration_lifecycle_hooks
}

moved {
  from = module.migration_user_data
  to   = module.migration_usw2.module.migration_user_data
}

moved {
  from = module.migration_launch_template
  to   = module.migration_usw2.module.migration_launch_template
}

moved {
  from = module.migration_recycle
  to   = module.migration_usw2.module.migration_recycle
}