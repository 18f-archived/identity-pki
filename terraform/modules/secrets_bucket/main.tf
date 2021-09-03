data "aws_caller_identity" "current" {
}

locals {
  inventory_bucket_arn = "arn:aws:s3:::${var.bucket_name_prefix}.s3-inventory.${data.aws_caller_identity.current.account_id}-${var.region}"
}

resource "aws_s3_bucket" "secrets" {
  bucket        = var.bucket_name
  acl           = "private"
  force_destroy = var.force_destroy

  policy = ""

  tags = {
    Name        = var.bucket_name_prefix
    Environment = "All"
  }

  versioning {
    enabled = true
  }

  logging {
    target_bucket = var.logs_bucket
    target_prefix = "${var.bucket_name}/"
  }

  server_side_encryption_configuration {
    rule {
      apply_server_side_encryption_by_default {
        sse_algorithm = "aws:kms"
      }
    }
  }
}

module "secrets_bucket_config" {
  source = "github.com/18F/identity-terraform//s3_config?ref=fe5cedbab370a69079261adb5e0ff1f7cd51acf8"
  depends_on = [aws_s3_bucket.secrets]

  bucket_name_prefix   = var.bucket_name_prefix
  bucket_name          = var.secrets_bucket_type
  region               = var.region
  inventory_bucket_arn = local.inventory_bucket_arn
}
