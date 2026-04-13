# modules/secrets/main.tf

terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.6"
    }
  }
}

locals {
  name_prefix   = "${var.project_name}-${var.environment}"
  secret_prefix = "${var.project_name}/${var.environment}"
}

# 
# Password Generation
# 

resource "random_password" "db" {
  length           = 32
  special          = true
  override_special = "!#$%&*()-_=+[]{}?"

  # Prevent regeneration on every plan - lifecycle is critical here.
  # If you rotate via Secrets Manager, Terraform will not fight you.
 
}

resource "random_password" "redis" {
  length           = 32
  special          = false
 

 
}

resource "random_password" "jwt_secret" {
  length  = 64
  special = false # JWT secrets are typically base64-safe

 
}

# 
# DB Credentials Secret
# 

resource "aws_secretsmanager_secret" "db_credentials" {
  name                    = "${local.secret_prefix}/db/credentials"
  description             = "RDS PostgreSQL credentials for ${local.name_prefix}"
  kms_key_id              = var.kms_key_arn
  recovery_window_in_days = var.recovery_window_in_days

  tags = {
    Name        = "${local.name_prefix}-db-credentials"
    Environment = var.environment
    Purpose     = "database-access"
  }
}

resource "aws_secretsmanager_secret_version" "db_credentials" {
  secret_id = aws_secretsmanager_secret.db_credentials.id

  secret_string = jsonencode({
    username = var.db_username
    password = random_password.db.result
    dbname   = var.db_name
    engine   = "postgres"
    port     = 5432
    # host is intentionally omitted here.
    # The database module outputs rds_endpoint; wire it via
    # aws_secretsmanager_secret_version "db_credentials_with_host"
    # in your root module after the database module runs.
    # See the pattern in prod/main.tf below.
    host = var.rds_endpoint
  })

  # If Secrets Manager rotation updates the version,
  # Terraform should not overwrite it on next apply.
  lifecycle {
    ignore_changes = [secret_string]
  }
}

# 
# Redis Credentials Secret
# 

resource "aws_secretsmanager_secret" "redis_credentials" {
  name                    = "${local.secret_prefix}/redis/credentials"
  description             = "ElastiCache Redis auth token for ${local.name_prefix}"
  kms_key_id              = var.kms_key_arn
  recovery_window_in_days = var.recovery_window_in_days

  tags = {
    Name        = "${local.name_prefix}-redis-credentials"
    Environment = var.environment
    Purpose     = "cache-access"
  }
}

resource "aws_secretsmanager_secret_version" "redis_credentials" {
  secret_id = aws_secretsmanager_secret.redis_credentials.id

  secret_string = jsonencode({
    auth_token = random_password.redis.result
    port       = 6379
    host       = var.redis_endpoint
  })

  
}

# 
# App Config Secret (JWT + environment metadata)
# 

resource "aws_secretsmanager_secret" "app_config" {
  name                    = "${local.secret_prefix}/app/config"
  description             = "Application configuration for ${local.name_prefix}"
  kms_key_id              = var.kms_key_arn
  recovery_window_in_days = var.recovery_window_in_days

  tags = {
    Name        = "${local.name_prefix}-app-config"
    Environment = var.environment
    Purpose     = "app-configuration"
  }
}

resource "aws_secretsmanager_secret_version" "app_config" {
  secret_id = aws_secretsmanager_secret.app_config.id

  secret_string = jsonencode({
    environment = var.environment
    aws_region  = var.aws_region
    log_level   = var.environment == "prod" ? "WARN" : "DEBUG"
    jwt_secret  = random_password.jwt_secret.result
  })

  
}

# 
# Automatic Rotation - DB Credentials
# 

data "aws_iam_policy_document" "rotation_assume" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["lambda.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "rotation" {
  name               = "${local.name_prefix}-secret-rotation-role"
  assume_role_policy = data.aws_iam_policy_document.rotation_assume.json

  tags = {
    Name        = "${local.name_prefix}-secret-rotation-role"
    Environment = var.environment
  }
}

resource "aws_iam_role_policy_attachment" "rotation_basic" {
  role       = aws_iam_role.rotation.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

resource "aws_iam_policy" "rotation" {
  name        = "${local.name_prefix}-rotation-policy"
  description = "Allows rotation Lambda to manage DB secret versions"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "SecretsManagerAccess"
        Effect = "Allow"
        Action = [
          "secretsmanager:DescribeSecret",
          "secretsmanager:GetSecretValue",
          "secretsmanager:PutSecretValue",
          "secretsmanager:UpdateSecretVersionStage"
        ]
        Resource = [aws_secretsmanager_secret.db_credentials.arn]
      },
      {
        Sid    = "KMSAccess"
        Effect = "Allow"
        Action = [
          "kms:Decrypt",
          "kms:GenerateDataKey",
          "kms:DescribeKey"
        ]
        Resource = [var.kms_key_arn]
      },
      # Rotation Lambda needs network access to reach RDS.
      # VPC config is set on the Lambda resource below.
      {
        Sid    = "EC2NetworkInterfaces"
        Effect = "Allow"
        Action = [
          "ec2:CreateNetworkInterface",
          "ec2:DescribeNetworkInterfaces",
          "ec2:DeleteNetworkInterface"
        ]
        Resource = ["*"]
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "rotation" {
  role       = aws_iam_role.rotation.name
  policy_arn = aws_iam_policy.rotation.arn
}

data "archive_file" "rotation" {
  type        = "zip"
  output_path = "${path.module}/lambda/rotation.zip"

  source {
    content  = <<-EOT
import boto3
import json
import logging
import psycopg2
import secrets
import string

logger = logging.getLogger()
logger.setLevel(logging.INFO)

def lambda_handler(event, context):
    arn   = event['SecretId']
    token = event['ClientRequestToken']
    step  = event['Step']

    client = boto3.client('secretsmanager')
    meta   = client.describe_secret(SecretId=arn)

    if not meta.get('RotationEnabled'):
        raise ValueError(f"Rotation not enabled for {arn}")

    stages = meta.get('VersionIdsToStages', {})
    if token not in stages:
        raise ValueError(f"Token {token} not found in secret versions")

    if 'AWSCURRENT' in stages.get(token, []):
        logger.info("Version already current, nothing to do")
        return

    if step == "createSecret":
        _create_secret(client, arn, token)
    elif step == "setSecret":
        _set_secret(client, arn, token)
    elif step == "testSecret":
        _test_secret(client, arn, token)
    elif step == "finishSecret":
        _finish_secret(client, arn, token, stages)
    else:
        raise ValueError(f"Unknown step: {step}")

def _generate_password(length=32):
    alphabet = string.ascii_letters + string.digits + "!#$%&*()-_=+[]{}?"
    return ''.join(secrets.choice(alphabet) for _ in range(length))

def _create_secret(client, arn, token):
    try:
        client.get_secret_value(SecretId=arn, VersionStage='AWSPENDING',
                                VersionId=token)
        logger.info("Pending version already exists")
        return
    except client.exceptions.ResourceNotFoundException:
        pass

    current = json.loads(
        client.get_secret_value(SecretId=arn, VersionStage='AWSCURRENT')['SecretString']
    )
    current['password'] = _generate_password()

    client.put_secret_value(
        SecretId=arn,
        ClientRequestToken=token,
        SecretString=json.dumps(current),
        VersionStages=['AWSPENDING']
    )

def _set_secret(client, arn, token):
    pending = json.loads(
        client.get_secret_value(SecretId=arn, VersionStage='AWSPENDING',
                                VersionId=token)['SecretString']
    )
    current = json.loads(
        client.get_secret_value(SecretId=arn, VersionStage='AWSCURRENT')['SecretString']
    )

    conn = psycopg2.connect(
        host=current['host'], port=current['port'],
        dbname=current['dbname'], user=current['username'],
        password=current['password'], connect_timeout=5
    )
    conn.autocommit = True
    with conn.cursor() as cur:
        cur.execute(
            "ALTER USER %s WITH PASSWORD %s",
            (pending['username'], pending['password'])
        )
    conn.close()

def _test_secret(client, arn, token):
    pending = json.loads(
        client.get_secret_value(SecretId=arn, VersionStage='AWSPENDING',
                                VersionId=token)['SecretString']
    )
    conn = psycopg2.connect(
        host=pending['host'], port=pending['port'],
        dbname=pending['dbname'], user=pending['username'],
        password=pending['password'], connect_timeout=5
    )
    conn.close()

def _finish_secret(client, arn, token, stages):
    current = [v for v, s in stages.items() if 'AWSCURRENT' in s]
    client.update_secret_version_stage(
        SecretId=arn,
        VersionStage='AWSCURRENT',
        MoveToVersionId=token,
        RemoveFromVersionId=current[0] if current else None
    )
    EOT
    filename = "rotation.py"
  }
}

resource "aws_lambda_function" "rotation" {
  filename         = data.archive_file.rotation.output_path
  function_name    = "${local.name_prefix}-secret-rotation"
  role             = aws_iam_role.rotation.arn
  handler          = "rotation.lambda_handler"
  runtime          = "python3.12"
  source_code_hash = data.archive_file.rotation.output_base64sha256
  timeout          = 30

  # Lambda must be in the VPC to reach RDS on its private endpoint
  vpc_config {
    subnet_ids         = var.private_subnet_ids
    security_group_ids = [var.lambda_security_group_id]
  }

  environment {
    variables = {
      ENVIRONMENT = var.environment
    }
  }

  tags = {
    Name        = "${local.name_prefix}-secret-rotation"
    Environment = var.environment
  }
}

resource "aws_lambda_permission" "rotation" {
  statement_id  = "AllowSecretsManager"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.rotation.function_name
  principal     = "secretsmanager.amazonaws.com"
  source_arn    = aws_secretsmanager_secret.db_credentials.arn
}

resource "aws_secretsmanager_secret_rotation" "db_credentials" {
  secret_id           = aws_secretsmanager_secret.db_credentials.id
  rotation_lambda_arn = aws_lambda_function.rotation.arn

  rotation_rules {
    automatically_after_days = var.environment == "prod" ? 30 : 90
  }

  depends_on = [aws_lambda_permission.rotation]
}