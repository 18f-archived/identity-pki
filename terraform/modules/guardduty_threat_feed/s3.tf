resource "aws_s3_bucket" "guardduty_threat_feed_s3_bucket" {
  bucket = local.gd_s3_bucket
  acl    = "private"

  logging {
    target_bucket = var.logs_bucket
    target_prefix = "${local.gd_s3_bucket}/"
  }

  tags = {
    feed = var.guardduty_threat_feed_name
  }

  server_side_encryption_configuration {
    rule {
      apply_server_side_encryption_by_default {
        sse_algorithm = "AES256"
      }
    }
  }

  versioning {
    enabled = true
  }

  lifecycle_rule {
    id      = "expire"
    prefix  = "/"
    enabled = true

    transition {
      storage_class = "INTELLIGENT_TIERING"
    }
    noncurrent_version_transition {
      storage_class = "INTELLIGENT_TIERING"
    }
    expiration {
      days = 2190
    }
    noncurrent_version_expiration {
      days = 2190
    }
  }
}

module "guardduty_threat_feed_s3_bucket_config" {
  source = "github.com/18F/identity-terraform//s3_config?ref=a6261020a94b77b08eedf92a068832f21723f7a2"

  bucket_name_override = aws_s3_bucket.guardduty_threat_feed_s3_bucket.id
  inventory_bucket_arn = var.inventory_bucket_arn
}
