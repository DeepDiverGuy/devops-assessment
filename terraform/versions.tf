terraform {
  required_version = ">= 1.10"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.80"
    }
  }

  # Remote state in S3 with native locking. The state key is passed at init time
  # (-backend-config="key=<env>/terraform.tfstate") so each environment has its own state.
  backend "s3" {
    bucket       = "devops-assessment-tfstate-850869059198"
    region       = "ap-southeast-1"
    encrypt      = true
    use_lockfile = true
  }
}

provider "aws" {
  region = var.region

  default_tags {
    tags = {
      Project     = "devops-assessment"
      Environment = var.environment
      ManagedBy   = "terraform"
    }
  }
}
