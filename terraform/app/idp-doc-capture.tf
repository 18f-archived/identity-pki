locals {
  doc_capture_s3_bucket_name_prefix = "login-gov-idp-doc-capture"
  doc_capture_key_alias_name        = "alias/${var.env_name}-idp-doc-capture"
  doc_capture_ssm_parameter_prefix  = "/${var.env_name}/idp/doc-capture/"
  doc_capture_domain_name           = var.env_name == "prod" ? "secure.${var.root_domain}" : "idp.${var.env_name}.${var.root_domain}"
}

resource "aws_kms_key" "idp_doc_capture" {
  description             = "IDP Doc Capture"
  deletion_window_in_days = 7
  enable_key_rotation     = true
}

resource "aws_kms_alias" "idp_doc_capture" {
  name          = local.doc_capture_key_alias_name
  target_key_id = aws_kms_key.idp_doc_capture.key_id
}

resource "aws_s3_bucket" "idp_doc_capture" {
  bucket        = "${local.doc_capture_s3_bucket_name_prefix}-${var.env_name}.${data.aws_caller_identity.current.account_id}-${var.region}"
  force_destroy = true
  tags = {
    Name = "${local.doc_capture_s3_bucket_name_prefix}-${var.env_name}.${data.aws_caller_identity.current.account_id}-${var.region}"
  }
}

resource "aws_s3_bucket_ownership_controls" "idp_doc_capture" {
  bucket = aws_s3_bucket.idp_doc_capture.id

  rule {
    object_ownership = "BucketOwnerPreferred"
  }
}

resource "aws_s3_bucket_acl" "idp_doc_capture" {
  bucket = aws_s3_bucket.idp_doc_capture.id
  acl    = "private"

  depends_on = [aws_s3_bucket_ownership_controls.idp_doc_capture]
}

resource "aws_s3_bucket_versioning" "idp_doc_capture" {
  bucket = aws_s3_bucket.idp_doc_capture.id

  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "idp_doc_capture" {
  bucket = aws_s3_bucket.idp_doc_capture.id

  rule {
    apply_server_side_encryption_by_default {
      kms_master_key_id = aws_kms_key.idp_doc_capture.arn
      sse_algorithm     = "aws:kms"
    }
  }
}

resource "aws_s3_bucket_logging" "idp_doc_capture" {
  bucket = aws_s3_bucket.idp_doc_capture.id

  target_bucket = "login-gov.s3-access-logs.${data.aws_caller_identity.current.account_id}-${var.region}"
  target_prefix = "${local.doc_capture_s3_bucket_name_prefix}-${var.env_name}.${data.aws_caller_identity.current.account_id}-${var.region}/"
}

resource "aws_s3_bucket_lifecycle_configuration" "idp_doc_capture" {
  bucket = aws_s3_bucket.idp_doc_capture.id

  rule {
    id     = "delete"
    status = "Enabled"

    expiration {
      days = 1
    }
    noncurrent_version_expiration {
      noncurrent_days = 1
    }
  }
}

resource "aws_s3_bucket_cors_configuration" "idp_doc_capture" {
  bucket = aws_s3_bucket.idp_doc_capture.id

  cors_rule {
    allowed_headers = ["*"]
    allowed_methods = ["POST", "PUT"]
    allowed_origins = ["https://${local.doc_capture_domain_name}"]
    expose_headers  = ["x-amz-request-id", "x-amz-id-2"]
  }
}

module "idp_doc_capture_bucket_config" {
  source = "github.com/18F/identity-terraform//s3_config?ref=6cdd1037f2d1b14315cc8c59b889f4be557b9c17"
  #source = "../../../identity-terraform/s3_config"

  bucket_name_override = aws_s3_bucket.idp_doc_capture.id
  region               = var.region
  inventory_bucket_arn = local.inventory_bucket_arn
}

resource "aws_ssm_parameter" "kms_key_alias" {
  name  = "${local.doc_capture_ssm_parameter_prefix}kms/alias"
  type  = "String"
  value = local.doc_capture_key_alias_name
}

resource "aws_ssm_parameter" "kms_key_arn" {
  name  = "${local.doc_capture_ssm_parameter_prefix}kms/arn"
  type  = "String"
  value = aws_kms_key.idp_doc_capture.arn
}

# Creates parameters but you need to set the values!
# Only parameters used by all IdP functions should be included
# TODO - Consider refactoring to place all IdP functions config
#        under a path like `/ENV/idp/functions`
resource "aws_ssm_parameter" "doc_capture_secrets" {
  for_each = var.doc_capture_secrets

  name        = "${local.doc_capture_ssm_parameter_prefix}${each.key}"
  description = each.value
  type        = "SecureString"
  overwrite   = false
  value       = "Starter value"

  lifecycle {
    ignore_changes = [
      value
    ]
  }
}
