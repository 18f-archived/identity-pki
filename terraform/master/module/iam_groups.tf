# Groups and group policy attachments

module "iam_groups" {
  source = "github.com/18F/identity-terraform//iam_assumegroup?ref=e7ad5ef38f724b31911248a74173e9fee3bbf045"
  #source = "../../../../identity-terraform/iam_assumegroup"

  group_role_map    = var.group_role_map
  master_account_id = var.master_account_id
  policy_depends_on = module.assume_roles.policy_arns
}
