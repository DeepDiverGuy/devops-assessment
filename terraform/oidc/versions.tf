terraform {
  required_version = ">= 1.10"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.80"
    }
  }

  backend "s3" {
    bucket       = "devops-assessment-tfstate-850869059198"
    key          = "github-oidc/terraform.tfstate"
    region       = "ap-southeast-1"
    encrypt      = true
    use_lockfile = true
  }
}

provider "aws" {
  region = var.region

  default_tags {
    tags = {
      Project   = "devops-assessment"
      ManagedBy = "terraform"
    }
  }
}

variable "region" {
  type    = string
  default = "ap-southeast-1"
}

variable "github_repo" {
  type    = string
  default = "DeepDiverGuy/devops-assessment"
}
