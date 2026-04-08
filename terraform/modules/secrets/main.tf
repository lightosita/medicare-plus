locals {
  name_prefix    = "${var.project_name}-${var.environment}"
  secret_prefix  = "${var.project_name}/${var.environment}"
}

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
    password = var.db_password
    dbname   = var.db_name
    engine   = "postgres"
    port     = 5432
  })
}

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
    auth_token = var.redis_password
    port       = 6379
  })
}

resource "aws_secretsmanager_secret" "app_config" {
  name                    = "${local.secret_prefix}/app/config"
  description             = "Application configuration secrets for ${local.name_prefix}"
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
    environment    = var.environment
    aws_region     = var.aws_region
    log_level      = var.environment == "prod" ? "WARN" : "DEBUG"
  })
}

resource "aws_secretsmanager_secret_rotation" "db_credentials" {
  secret_id           = aws_secretsmanager_secret.db_credentials.id
  rotation_lambda_arn = aws_lambda_function.rotation.arn

  rotation_rules {
    automatically_after_days = 30
  }

  depends_on = [aws_lambda_permission.rotation]
}

data "aws_iam_policy_document" "rotation_lambda_assume" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["lambda.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "rotation_lambda" {
  name               = "${local.name_prefix}-secret-rotation-role"
  assume_role_policy = data.aws_iam_policy_document.rotation_lambda_assume.json

  tags = {
    Name        = "${local.name_prefix}-secret-rotation-role"
    Environment = var.environment
  }
}

resource "aws_iam_role_policy_attachment" "rotation_lambda_basic" {
  role       = aws_iam_role.rotation_lambda.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

resource "aws_iam_policy" "rotation_lambda_secrets" {
  name        = "${local.name_prefix}-rotation-secrets-policy"
  description = "Allows rotation Lambda to manage secret versions"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "secretsmanager:DescribeSecret",
          "secretsmanager:GetSecretValue",
          "secretsmanager:PutSecretValue",
          "secretsmanager:UpdateSecretVersionStage"
        ]
        Resource = [
          aws_secretsmanager_secret.db_credentials.arn
        ]
      },
      {
        Effect = "Allow"
        Action = [
          "kms:Decrypt",
          "kms:GenerateDataKey",
          "kms:DescribeKey"
        ]
        Resource = [var.kms_key_arn]
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "rotation_lambda_secrets" {
  role       = aws_iam_role.rotation_lambda.name
  policy_arn = aws_iam_policy.rotation_lambda_secrets.arn
}

data "archive_file" "rotation_lambda" {
  type        = "zip"
  output_path = "${path.module}/lambda/rotation.zip"

  source {
    content  = <<-EOT
      import boto3
      import json

      def lambda_handler(event, context):
          arn = event['SecretId']
          token = event['ClientRequestToken']
          step = event['Step']

          client = boto3.client('secretsmanager')

          if step == "createSecret":
              client.put_secret_value(
                  SecretId=arn,
                  ClientRequestToken=token,
                  SecretString=json.dumps({"rotated": True}),
                  VersionStages=['AWSPENDING']
              )
          elif step == "finishSecret":
              client.update_secret_version_stage(
                  SecretId=arn,
                  VersionStage='AWSCURRENT',
                  MoveToVersionId=token,
                  RemoveFromVersionId=client.describe_secret(
                      SecretId=arn
                  )['VersionIdsToStages'].get('AWSCURRENT', [None])[0]
              )
    EOT
    filename = "rotation.py"
  }
}

resource "aws_lambda_function" "rotation" {
  filename         = data.archive_file.rotation_lambda.output_path
  function_name    = "${local.name_prefix}-secret-rotation"
  role             = aws_iam_role.rotation_lambda.arn
  handler          = "rotation.lambda_handler"
  runtime          = "python3.12"
  source_code_hash = data.archive_file.rotation_lambda.output_base64sha256
  timeout          = 30

  environment {
    variables = {
      ENVIRONMENT = var.environment
    }
  }

  tags = {
    Name        = "${local.name_prefix}-secret-rotation"
    Environment = var.environment
    Purpose     = "secret-rotation"
  }
}

resource "aws_lambda_permission" "rotation" {
  statement_id  = "AllowSecretsManagerInvocation"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.rotation.function_name
  principal     = "secretsmanager.amazonaws.com"
  source_arn    = aws_secretsmanager_secret.db_credentials.arn
}