module "pivcac_user_data" {
  source = "../modules/bootstrap/"

  role                   = "pivcac"
  env                    = var.env_name
  domain                 = var.root_domain
  s3_secrets_bucket_name = data.aws_s3_bucket.secrets.bucket
  sns_topic_arn          = var.slack_events_sns_hook_arn

  chef_download_url    = var.chef_download_url
  chef_download_sha256 = var.chef_download_sha256

  # identity-devops-private variables
  private_s3_ssh_key_url = local.bootstrap_private_s3_ssh_key_url
  private_git_clone_url  = var.bootstrap_private_git_clone_url
  private_git_ref        = local.bootstrap_private_git_ref

  # identity-devops variables
  main_s3_ssh_key_url  = local.bootstrap_main_s3_ssh_key_url
  main_git_clone_url   = var.bootstrap_main_git_clone_url
  main_git_ref_map     = var.bootstrap_main_git_ref_map
  main_git_ref_default = local.bootstrap_main_git_ref_default

  # proxy variables
  proxy_server        = var.proxy_server
  proxy_port          = var.proxy_port
  no_proxy_hosts      = var.no_proxy_hosts
  proxy_enabled_roles = var.proxy_enabled_roles
}

module "pivcac_launch_template" {
  source = "github.com/18F/identity-terraform//launch_template?ref=6cdd1037f2d1b14315cc8c59b889f4be557b9c17"
  #source = "../../../identity-terraform/launch_template"
  role           = "pivcac"
  env            = var.env_name
  root_domain    = var.root_domain
  ami_id_map     = var.ami_id_map_uw2
  default_ami_id = local.account_rails_ami_id

  instance_type             = var.instance_type_pivcac
  use_spot_instances        = var.use_spot_instances
  iam_instance_profile_name = aws_iam_instance_profile.pivcac.name
  security_group_ids        = [aws_security_group.pivcac.id, module.network_uw2.base_id]

  user_data = module.pivcac_user_data.rendered_cloudinit_config

  template_tags = {
    main_git_ref = module.pivcac_user_data.main_git_ref
  }
}

module "pivcac_lifecycle_hooks" {
  source = "github.com/18F/identity-terraform//asg_lifecycle_notifications?ref=6cdd1037f2d1b14315cc8c59b889f4be557b9c17"
  #source = "../../../identity-terraform/asg_lifecycle_notifications"
  asg_name = aws_autoscaling_group.pivcac.name
}

module "pivcac_recycle" {
  source = "github.com/18F/identity-terraform//asg_recycle?ref=6cdd1037f2d1b14315cc8c59b889f4be557b9c17"
  #source = "../../../identity-terraform/asg_recycle"

  asg_name       = aws_autoscaling_group.pivcac.name
  normal_min     = var.asg_pivcac_min
  normal_max     = var.asg_pivcac_max
  normal_desired = var.asg_pivcac_desired
  scale_schedule = var.autoscaling_schedule_name
  time_zone      = var.autoscaling_time_zone
}

resource "aws_iam_instance_profile" "pivcac" {
  name = "${var.env_name}_pivcac_instance_profile"
  role = module.application_iam_roles.pivcac_iam_role_name
}

resource "aws_autoscaling_group" "pivcac" {
  name = "${var.env_name}-pivcac"

  launch_template {
    id      = module.pivcac_launch_template.template_id
    version = "$Latest"
  }

  min_size         = var.asg_pivcac_min == 0 ? 0 : var.asg_pivcac_min
  max_size         = var.asg_pivcac_max == 0 ? var.asg_pivcac_desired * 2 : var.asg_pivcac_max
  desired_capacity = var.asg_pivcac_desired

  wait_for_capacity_timeout = 0

  # Use the same subnet as the IDP.
  vpc_zone_identifier = [for subnet in module.network_uw2.app_subnet : subnet.id]

  load_balancers = [aws_elb.pivcac.id]

  health_check_type         = "ELB"
  health_check_grace_period = 1

  termination_policies = ["OldestInstance"]

  # Because bootstrapping takes so long, we terminate manually in prod
  # We also would want to switch to an ELB health check before allowing AWS
  # to automatically terminate instances. Right now the ASG can't tell if
  # instance bootstrapping completed successfully.
  # https://github.com/18F/identity-devops-private/issues/337
  protect_from_scale_in = var.asg_prevent_auto_terminate == 1 ? true : false

  enabled_metrics = var.asg_enabled_metrics

  tag {
    key                 = "Name"
    value               = "asg-${var.env_name}-pivcac"
    propagate_at_launch = true
  }
  tag {
    key                 = "client"
    value               = var.client
    propagate_at_launch = true
  }
  tag {
    key                 = "prefix"
    value               = "pivcac"
    propagate_at_launch = true
  }
  tag {
    key                 = "domain"
    value               = "${var.env_name}.${var.root_domain}"
    propagate_at_launch = true
  }
  tag {
    key                 = "fisma"
    value               = var.fisma_tag
    propagate_at_launch = true
  }

  depends_on = [
    module.outboundproxy_uw2.proxy_asg_name,
    module.migration_usw2.migration_asg_name,
    aws_cloudwatch_log_group.nginx_access_log
  ]
}

resource "aws_elb" "pivcac" {
  name            = "${var.env_name}-pivcac"
  security_groups = [aws_security_group.web.id]
  subnets         = [for subnet in aws_subnet.public-ingress : subnet.id]


  access_logs {
    bucket        = "login-gov.elb-logs.${data.aws_caller_identity.current.account_id}-${var.region}"
    bucket_prefix = "${var.env_name}/pivcac"
  }

  listener {
    instance_port     = 443
    instance_protocol = "tcp"
    lb_port           = 443
    lb_protocol       = "tcp"
  }

  health_check {
    target              = "HTTPS:443/health_check"
    healthy_threshold   = 3
    unhealthy_threshold = 3
    interval            = 10
    timeout             = 3
  }
}

resource "aws_s3_bucket" "pivcac_cert_bucket" {
  bucket = "login-gov-pivcac-${var.env_name}.${data.aws_caller_identity.current.account_id}-${var.region}"

  tags = {
    Name = "login-gov-pivcac-${var.env_name}.${data.aws_caller_identity.current.account_id}-${var.region}"
  }
}

resource "aws_s3_bucket_policy" "pivcac_cert_bucket" {
  bucket = aws_s3_bucket.pivcac_cert_bucket.id
  policy = data.aws_iam_policy_document.pivcac_bucket_policy.json
}

resource "aws_s3_bucket_server_side_encryption_configuration" "pivcac_cert_bucket" {
  bucket = aws_s3_bucket.pivcac_cert_bucket.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket" "pivcac_public_cert_bucket" {
  bucket = "login-gov-pivcac-public-cert-${var.env_name}.${data.aws_caller_identity.current.account_id}-${var.region}"
  tags = {
    Name = "login-gov-pivcac-public-cert-${var.env_name}.${data.aws_caller_identity.current.account_id}-${var.region}"
  }
}

resource "aws_s3_bucket_versioning" "pivcac_public_cert_bucket" {
  bucket = aws_s3_bucket.pivcac_public_cert_bucket.id

  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "pivcac_public_cert_bucket" {
  bucket = aws_s3_bucket.pivcac_public_cert_bucket.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_policy" "pivcac_public_cert_bucket" {
  bucket = aws_s3_bucket.pivcac_public_cert_bucket.id
  policy = data.aws_iam_policy_document.pivcac_public_cert_bucket_policy.json
}

resource "aws_s3_bucket_lifecycle_configuration" "pivcac_public_cert_bucket" {
  bucket = aws_s3_bucket.pivcac_public_cert_bucket.id

  rule {
    id     = "expiration"
    status = "Enabled"

    noncurrent_version_expiration {
      noncurrent_days = 60
    }

    expiration {
      days = 60
    }
  }
}

module "pivcac_cert_bucket_config" {
  source = "github.com/18F/identity-terraform//s3_config?ref=6cdd1037f2d1b14315cc8c59b889f4be557b9c17"
  #source = "../../../identity-terraform/s3_config"
  depends_on = [aws_s3_bucket.pivcac_cert_bucket]

  bucket_name_override = aws_s3_bucket.pivcac_cert_bucket.id
  region               = var.region
  inventory_bucket_arn = local.inventory_bucket_arn
}


module "pivcac_public_cert_bucket_config" {
  source = "github.com/18F/identity-terraform//s3_config?ref=6cdd1037f2d1b14315cc8c59b889f4be557b9c17"
  #source = "../../../identity-terraform/s3_config"
  depends_on = [aws_s3_bucket.pivcac_public_cert_bucket]

  bucket_name_override = aws_s3_bucket.pivcac_public_cert_bucket.id
  region               = var.region
  inventory_bucket_arn = local.inventory_bucket_arn
}

data "aws_iam_policy_document" "pivcac_bucket_policy" {
  # allow pivcac hosts to read and write their SSL certs
  statement {
    actions = [
      "s3:GetObject",
      "s3:PutObject",
      "s3:PutObjectAcl",
    ]
    principals {
      type = "AWS"
      identifiers = [
        module.application_iam_roles.pivcac_iam_role_arn,
      ]
    }

    resources = [
      "arn:aws:s3:::login-gov-pivcac-${var.env_name}.${data.aws_caller_identity.current.account_id}-${var.region}",
      "arn:aws:s3:::login-gov-pivcac-${var.env_name}.${data.aws_caller_identity.current.account_id}-${var.region}/*",
    ]
  }
}

data "aws_iam_policy_document" "pivcac_public_cert_bucket_policy" {
  statement {
    actions = [
      "s3:PutObject",
    ]
    principals {
      type = "AWS"
      identifiers = [
        module.application_iam_roles.pivcac_iam_role_arn,
      ]
    }

    resources = [
      "arn:aws:s3:::login-gov-pivcac-public-cert-${var.env_name}.${data.aws_caller_identity.current.account_id}-${var.region}",
      "arn:aws:s3:::login-gov-pivcac-public-cert-${var.env_name}.${data.aws_caller_identity.current.account_id}-${var.region}/*",
    ]
  }
}

