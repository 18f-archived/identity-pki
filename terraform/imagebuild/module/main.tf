terraform {
  required_version = ">= 1.0.2"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 3.52.0"
    }
    github = {
      source  = "integrations/github"
      version = "~> 4.13.0"
    }
  }
}
