data "aws_eips" "all" {
}

# CMK and policy document
resource "aws_kms_key" "escrow_kms" {
  description             = "${var.env_name} KMS key for the escrow s3 bucket"
  deletion_window_in_days = 10

  # HOLD until release v265 (2023-06-13). Permissions need to apply prior to modifications.
  #  enable_key_rotation = true

  policy = module.application_iam_roles.escrow_kms_policy_document_json
  tags = {
    Name        = "${var.env_name}-escrow-s3"
    Environment = "${var.env_name}"
  }
}

resource "aws_kms_alias" "escrow_kms" {
  name          = "alias/${var.env_name}-escrow-s3"
  target_key_id = aws_kms_key.escrow_kms.key_id
}

# Escrow S3 Bucket Setup
resource "aws_s3_bucket" "escrow" {
  bucket = "login-gov-escrow-${var.env_name}.${data.aws_caller_identity.current.account_id}-${var.region}"
  tags = {
    Environment = var.env_name
  }
}

resource "aws_s3_bucket_metric" "escrow-bucket-metrics" {
  bucket = aws_s3_bucket.escrow.bucket
  name   = "${var.env_name}EntireBucket"
}

resource "aws_s3_bucket_logging" "escrow" {
  bucket = aws_s3_bucket.escrow.id

  target_bucket = "login-gov.s3-access-logs.${data.aws_caller_identity.current.account_id}-${var.region}"
  target_prefix = "${aws_s3_bucket.escrow.id}/"
}

resource "aws_s3_bucket_lifecycle_configuration" "escrow" {
  bucket = aws_s3_bucket.escrow.id

  rule {
    id = "ExpireObjects"
    expiration {
      days = var.escrow_content_expiration
    }
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "escrow" {
  bucket = aws_s3_bucket.escrow.bucket

  rule {
    apply_server_side_encryption_by_default {
      kms_master_key_id = aws_kms_key.escrow_kms.arn
      sse_algorithm     = "aws:kms"
    }
  }
}

resource "aws_s3_bucket_versioning" "escrow" {
  bucket = aws_s3_bucket.escrow.id
  versioning_configuration {
    status = "Disabled"
  }
}

resource "aws_s3_bucket_ownership_controls" "escrow" {
  bucket = aws_s3_bucket.escrow.id

  rule {
    object_ownership = "BucketOwnerPreferred"
  }
}

resource "aws_s3_bucket_acl" "escrow" {
  bucket = aws_s3_bucket.escrow.id
  acl    = "private"

  depends_on = [aws_s3_bucket_ownership_controls.escrow]
}

# Explicit Deny for address not in the VPC or on the GSA network
resource "aws_s3_bucket_policy" "escrow" {
  bucket = aws_s3_bucket.escrow.id
  policy = data.aws_iam_policy_document.escrow_deny.json
}

# <env>_idp_iam_role and <env>_worker_iam_role policy to access escrow S3 Bucket
# Only allows encrypt/reencrypt and push but no decrypt/get from the instances
# Key permissions are managed at the key policy level not the roles
data "aws_iam_policy_document" "escrow_write" {
  statement {
    sid    = "AllowAttemptsBucketList"
    effect = "Allow"
    actions = [
      "s3:ListBucket"
    ]
    resources = [
      aws_s3_bucket.escrow.arn
    ]
  }
  statement {
    sid    = "AllowAttemptsBucketGetPut"
    effect = "Allow"
    actions = [
      "s3:PutObject"
    ]
    resources = [
      "${aws_s3_bucket.escrow.arn}/*"
    ]
  }
}

# Deny policy for escrow bucket
data "aws_iam_policy_document" "escrow_deny" {
  # Deny from addresses not in our network
  statement {
    sid    = "DenyUnauthorizedAccess"
    effect = "Deny"
    principals {
      type = "AWS"
      identifiers = [
        module.application_iam_roles.idp_iam_role_arn,
        module.application_iam_roles.worker_iam_role_arn,
        "arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/EscrowRead"
      ]
    }
    actions = [
      "s3:ListBucket",
      "s3:GetObject",
      "s3:PutObject",
      "s3:AbortMultipartUpload",
      "s3:GetObjectAcl",
      "s3:GetObjectAttributes",
      "s3:GetObjectLegalHold",
      "s3:GetObjectRetention",
      "s3:GetObjectTagging",
      "s3:GetObjectTorrent",
      "s3:GetObjectVersion",
      "s3:GetObjectVersionAcl",
      "s3:GetObjectVersionAttributes",
      "s3:GetObjectVersionForReplication",
      "s3:GetObjectVersionTagging",
      "s3:GetObjectVersionTorrent",
      "s3:PutObjectLegalHold",
      "s3:PutObjectRetention",
      "s3:PutObjectTagging",
      "s3:PutObjectVersionTagging",
      "s3:ReplicateObject",
      "s3:RestoreObject",
    ]

    resources = [
      aws_s3_bucket.escrow.arn,
      "${aws_s3_bucket.escrow.arn}/*",
    ]

    # GSA VPC CIDR
    # 159 - AnyConnect
    condition {
      test     = "NotIpAddress"
      variable = "aws:SourceIP"
      values = [
        "159.142.0.0/16",
      ]
    }
    # VPC CIDR Blocks
    condition {
      test     = "NotIpAddress"
      variable = "aws:VpcSourceIP"
      values   = [aws_vpc_ipv4_cidr_block_association.secondary_cidr.cidr_block]
    }
  }
}
