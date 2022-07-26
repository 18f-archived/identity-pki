data "aws_caller_identity" "current" {
}

module "git2s3_src" {
  count = data.aws_caller_identity.current.account_id == "894947205914" ? 1 : 0
  #source = "../../../../identity-terraform/git2s3_artifacts"
  source = "github.com/18F/identity-terraform//git2s3_artifacts?ref=5d344d205dd09eb85d5de1ff1081c4a598afe433"
  providers = {
    aws = aws.usw2
  }

  git2s3_stack_name = "CodeSync-IdentityBaseImage"
  external_account_ids = [
    "555546682965",
    "917793222841",
    "034795980528",
    "217680906704",
  ]
  #artifact_bucket      = "login-gov-public-artifacts-us-west-2"
  bucket_name_prefix = "login-gov"
  sse_algorithm      = "AES256"
}
