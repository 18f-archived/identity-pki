variable "region" {
  default = "us-west-2"
}

variable "fisma_tag" {
  default = "Q-LG"
}

variable "ami_types" {
  description = "Names of the types of AMIs being created (base/rails by default)."
  type        = list(string)
  default = [
    "base",
    "rails"
  ]
}

variable "image_build_nat_eip" {
  description = <<EOM
Elastic IP address for the NAT gateway.
Must already be allocated via other means.
EOM
  type        = string
}

variable "image_build_private_cidr" {
  description = "CIDR block for the public subnet 1"
  type        = string
  default     = "10.0.11.0/24"
}

variable "image_build_public_cidr" {
  description = "CIDR block for the public subnet 1"
  type        = string
  default     = "10.0.1.0/24"
}

variable "image_build_vpc_cidr" {
  description = "CIDR block for the VPC"
  type        = string
  default     = "10.0.0.0/19"
}

variable "artifact_bucket" {
  default = "login-gov-public-artifacts-us-west-2"
}

variable "code_branch" {
  description = "Name of the identity-base-image branch used for builds/pipelines."
  type        = string
  default     = "main"
}

variable "packer_config" {
  description = <<DESC
Map of key/value pairs for Packer configs consistent in all AMI types in account.
Main number for os_version and ami_filter_name MUST be the same as var.os_number.
DESC
  type        = map(string)
  default = {
    aws_delay_seconds       = "60"
    aws_max_attempts        = "50"
    encryption              = "true"
    root_vol_size           = "40"
    data_vol_size           = "100"
    deregister_existing_ami = "false"
    delete_ami_snapshots    = "false"
    chef_version            = "17.5.22" # also passed to CFN as ChefVersion parameter
    os_version              = "Ubuntu 20.04"
    ami_owner_id            = "679593333241",
    ami_filter_name         = "ubuntu-pro-fips-server/images/hvm-ssd/ubuntu-focal-20.04-amd64*"
  }
}

variable "ami_regions" {
  description = <<EOM
List of region(s) where AMIs should exist. AMIs are created in us-west-2 and will be
copied to other regions IFF this variable has more than one region listed.
EOM
  type        = list(string)
  default     = ["us-west-2", "us-east-1"]
}

variable "os_number" {
  description = <<DESC
REQUIRED. Main version number of Ubuntu Pro FIPS used in buildspec.yml file from
identity-base-image repo and .var.hcl files from public-artifacts bucket.
Passed into CloudFormation template as UbuntuVersion parameter. MUST match numbers
in os_version and ami_filter_name values in var.packer_config above.
DESC
  type        = string
  default     = "20"
}

variable "trigger_source" {
  description = <<DESC
Which service can trigger the CodePipeline which runs the ImageBuild CodeBuild project.
Options are 'S3', 'CloudWatch', or 'Both'.
DESC
  type        = string
  default     = "Both"
}

variable "packer_version" {
  description = <<DESC
REQUIRED. Packer version used in buildspec.yml file from identity-base-image repo.
Passed into CloudFormation template as PackerVersion parameter.
DESC
  type        = string
  default     = "1.7.2"
}

variable "berkshelf_version" {
  description = <<DESC
REQUIRED. Berkshelf version used in buildspec.yml file from identity-base-image repo.
Passed into CloudFormation template as BerkshelfVersion parameter.
DESC
  type        = string
  default     = "7.1.0"
}
