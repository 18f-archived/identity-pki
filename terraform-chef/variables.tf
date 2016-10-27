variable "access_key" {}
variable "ami_id" {}
variable "app_sg_ssh_cidr_blocks" {type="list"}
variable "app_subnet_cidr_block" {}
variable "app2_subnet_cidr_block" {}
variable "bucket" { default = "login_dot_gov_terraform_state" }
variable "chef_ami_id" {}
variable "client" {}
variable "key_name" {}
variable "name" { default = "login" }
variable "region" { default = "us-west-2" }
variable "secret_key" {}
variable "subnet_cidr_block_chef" { default = "172.16.11.0/28" }
variable "vpc_cidr_block_chef" { default = "172.16.11.0/27" }


data "terraform_remote_state" "app-dev" {
  backend = "s3"
  config {
    bucket = "${var.bucket}"
    key = "terraform-app/terraform-dev.tfstate"
    region = "us-east-1"
  }
}

data "terraform_remote_state" "app-qa" {
  backend = "s3"
  config {
    bucket = "${var.bucket}"
    key = "terraform-app/terraform-qa.tfstate"
    region = "us-east-1"
  }
}

data "terraform_remote_state" "app-pt" {
  backend = "s3"
  config {
    bucket = "${var.bucket}"
    key = "terraform-app/terraform-pt.tfstate"
    region = "us-east-1"
  }
}

data "terraform_remote_state" "app-tf" {
  backend = "s3"
  config {
    bucket = "${var.bucket}"
    key = "terraform-app/terraform-tf.tfstate"
    region = "us-east-1"
  }
}
