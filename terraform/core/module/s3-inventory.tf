# These modules are for TEMPORARY use while cleanup/audit work is performed on the S3 buckets in our core accounts.
# https://github.com/18F/identity-devops/issues/2657

module "s3_inventory_uw2" {
  source = "github.com/18F/identity-terraform//s3_batch_inventory?ref=2643d71568554cfd9abae37bad703f0482ba9c99"
  #source = "../../../../identity-terraform/s3_batch_inventory"

  log_bucket   = "login-gov.s3-logs.${data.aws_caller_identity.current.account_id}-${var.region}"
  bucket_prefix = "login-gov"
  bucket_list   = var.bucket_list_uw2
}

# TODO: move this resource to all/ (if buckets will be created in us-east-1)
# OR redesign the s3-log bucket module to be multiregion.
resource "aws_s3_bucket" "s3_logs_ue1" {
  provider = aws.us-east-1

  bucket = "login-gov.s3-logs.${data.aws_caller_identity.current.account_id}-us-east-1"
  region = "us-east-1"
  acl    = "log-delivery-write"
  policy = ""

  versioning {
    enabled = true
  }

  lifecycle_rule {
    id      = "expirelogs"
    enabled = true

    prefix = "/"

    transition {
      days          = 30
      storage_class = "STANDARD_IA"
    }

    transition {
      days          = 365
      storage_class = "GLACIER"
    }

    expiration {
      # 5 years
      days = 1825
    }
  }

  server_side_encryption_configuration {
    rule {
      apply_server_side_encryption_by_default {
        sse_algorithm = "aws:kms"
      }
    }
  }

  lifecycle {
    prevent_destroy = true
  }
}


module "s3_inventory_ue1" {
  source = "github.com/18F/identity-terraform//s3_batch_inventory?ref=2643d71568554cfd9abae37bad703f0482ba9c99"
  #source = "../../../../identity-terraform/s3_batch_inventory"
  providers = {
    aws = aws.us-east-1
  }

  region        = "us-east-1"
  log_bucket    = aws_s3_bucket.s3_logs_ue1.id
  bucket_prefix = "login-gov"
  bucket_list   = var.bucket_list_ue1
}
