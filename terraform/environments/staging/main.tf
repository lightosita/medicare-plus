terraform {
  required_version = ">= 1.6.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.6"
    }
    archive = {
      source  = "hashicorp/archive"
      version = "~> 2.4"
    }
  }

  data "aws_acm_certificate" "main" {
  domain      = "babest.online"
  statuses    = ["ISSUED"]
  most_recent = true
}

  backend "s3" {
    bucket         = "light-teleios-s3-medicare-state-221693237976-us-east-1-an"
    key            = "prod/terraform.tfstate"
    region         = "us-east-1"
    encrypt        = true
    use_lockfile   = true
  }
}

provider "aws" {
  region = var.aws_region

  default_tags {
    tags = {
      Project     = "medicare-plus"
      Environment = "staging"
      ManagedBy   = "terraform"
      Owner       = "teleios-light"
    }
  }
}

data "aws_caller_identity" "current" {}

module "kms" {
  source = "../../modules/kms"

  environment             = var.environment
  project_name            = var.project_name
  aws_region              = var.aws_region
  deletion_window_in_days = 0
  enable_key_rotation     = true
}

module "networking" {
  source = "../../modules/networking"

  environment           = var.environment
  project_name          = var.project_name
  vpc_cidr              = var.vpc_cidr
  availability_zones    = var.availability_zones
  public_subnet_cidrs   = var.public_subnet_cidrs
  private_subnet_cidrs  = var.private_subnet_cidrs
  isolated_subnet_cidrs = var.isolated_subnet_cidrs
  enable_nat_gateway    = true
  single_nat_gateway    = true
}

module "iam" {
  source = "../../modules/iam"

  environment      = var.environment
  project_name     = var.project_name
  aws_region       = var.aws_region
  aws_account_id   = data.aws_caller_identity.current.account_id
  kms_main_key_arn = module.kms.main_key_arn
  kms_rds_key_arn  = module.kms.rds_key_arn
  kms_s3_key_arn   = module.kms.s3_key_arn
}

module "secrets" {
  source = "../../modules/secrets"

  environment             = var.environment
  project_name            = var.project_name
  aws_region              = var.aws_region
  kms_key_arn             = module.kms.main_key_arn
  db_username             = var.db_username
  db_password             = var.db_password
  db_name                 = var.db_name
  redis_password          = var.redis_password
  recovery_window_in_days = 7
}

module "storage" {
  source = "../../modules/storage"

  environment            = var.environment
  project_name           = var.project_name
  kms_s3_key_arn         = module.kms.s3_key_arn
  imaging_lifecycle_days = 30
  log_retention_days     = 90
  enable_replication     = false
  replication_region     = "us-west-2"
}

module "database" {
  source = "../../modules/database"

  environment             = var.environment
  project_name            = var.project_name
  aws_region              = var.aws_region
  vpc_id                  = module.networking.vpc_id
  isolated_subnet_ids     = module.networking.isolated_subnet_ids
  rds_security_group_id   = module.networking.rds_security_group_id
  redis_security_group_id = module.networking.redis_security_group_id
  kms_rds_key_arn         = module.kms.rds_key_arn
  db_username             = var.db_username
  db_password             = var.db_password
  db_name                 = var.db_name
  db_instance_class       = var.db_instance_class
  redis_node_type         = var.redis_node_type
  redis_password          = var.redis_password
  backup_retention_period = 7
  multi_az                = false
  deletion_protection     = false
}

module "notifications" {
  source = "../../modules/notifications"

  environment               = var.environment
  project_name              = var.project_name
  aws_region                = var.aws_region
  vpc_id                    = module.networking.vpc_id
  private_subnet_ids        = module.networking.private_subnet_ids
  ecs_security_group_id     = module.networking.ecs_security_group_id
  lambda_role_arn           = module.iam.lambda_emergency_role_arn
  kms_main_key_arn          = module.kms.main_key_arn
  db_credentials_secret_arn = module.secrets.db_credentials_secret_arn
}

module "compute" {
  source = "../../modules/compute"

  environment                  = var.environment
  project_name                 = var.project_name
  aws_region                   = var.aws_region
  vpc_id                       = module.networking.vpc_id
  public_subnet_ids            = module.networking.public_subnet_ids
  private_subnet_ids           = module.networking.private_subnet_ids
  alb_security_group_id        = module.networking.alb_security_group_id
  ecs_security_group_id        = module.networking.ecs_security_group_id
  ecs_task_execution_role_arn  = module.iam.ecs_task_execution_role_arn
  ecs_task_role_arn            = module.iam.ecs_task_role_arn
  db_credentials_secret_arn    = module.secrets.db_credentials_secret_arn
  redis_credentials_secret_arn = module.secrets.redis_credentials_secret_arn
  app_config_secret_arn        = module.secrets.app_config_secret_arn
  app_image                    = var.app_image
  app_cpu                      = var.app_cpu
  app_memory                   = var.app_memory
  app_desired_count            = var.app_desired_count
  app_min_count                = var.app_min_count
  app_max_count                = var.app_max_count
  certificate_arn              = var.certificate_arn
  rds_endpoint                 = module.database.rds_endpoint
  redis_endpoint               = module.database.redis_endpoint
}