terraform {
  required_version = ">= 1.6.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
backend "s3" {
    bucket       = "light-teleios-s3-medicare-state-221693237976-us-east-1-an"
    key          = "prod/terraform.tfstate"
    region       = "us-east-1"
    encrypt      = true
    use_lockfile = true
  }
}

provider "aws" {
  region = var.aws_region

  default_tags {
    tags = {
      Project     = "medicare-plus"
      Environment = "prod"
      ManagedBy   = "terraform"
      Owner       = "teleios-cloud-team"
    }
  }
}