terraform {
  required_version = ">= 1.6.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }

  cloud {
    organization = "Teleios"
    workspaces {
      name = "teleios-light-dev"
    }
  }
}

provider "aws" {
  region = var.aws_region

  default_tags {
    tags = {
      Project     = "medicare-plus"
      Environment = var.environment
      ManagedBy   = "terraform"
      Owner       = "teleios-cloud-team"
    }
  }
}
