# These modules are for TEMPORARY use while cleanup/audit work is performed on the S3 buckets in our core accounts.
# https://github.com/18F/identity-devops/issues/2657

module "s3_inventory_uw2" {
  source = "github.com/18F/identity-terraform//s3_batch_inventory?ref=21a2ce16cf1dbf85822c9005d72f8d17cb9dbe4b"
  #source = "../../../../identity-terraform/s3_batch_inventory"

  bucket_list          = var.bucket_list_uw2
  inventory_bucket_arn = "arn:aws:s3:::login-gov.s3-inventory.${data.aws_caller_identity.current.account_id}-us-west-2"
}

module "s3_config_ue1" {
  source = "github.com/18F/identity-terraform//state_bucket?ref=eaabb7c80efcbce9fab28575ef4111e1e8eaa346"
  #source = "../../../../identity-terraform/state_bucket"
  providers = {
    aws = aws.us-east-1
  }

  remote_state_enabled = 0
  region               = "us-east-1"
  bucket_name_prefix   = "login-gov"
  sse_algorithm        = "AES256"
}

module "s3_inventory_ue1" {
  source    = "github.com/18F/identity-terraform//s3_batch_inventory?ref=21a2ce16cf1dbf85822c9005d72f8d17cb9dbe4b"
  #source   = "../../../../identity-terraform/s3_batch_inventory"
  providers = {
    aws = aws.us-east-1
  }

  bucket_list          = var.bucket_list_ue1
  inventory_bucket_arn = module.s3_config_ue1.inventory_bucket_arn
}
