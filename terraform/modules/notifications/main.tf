locals {
  name_prefix = "${var.project_name}-${var.environment}"
}

resource "aws_sns_topic" "emergency" {
  name              = "${local.name_prefix}-emergency"
  kms_master_key_id = var.kms_main_key_arn

  tags = {
    Name        = "${local.name_prefix}-emergency"
    Environment = var.environment
    Purpose     = "emergency-alerts"
  }
}

resource "aws_sns_topic" "appointments" {
  name              = "${local.name_prefix}-appointments"
  kms_master_key_id = var.kms_main_key_arn

  tags = {
    Name        = "${local.name_prefix}-appointments"
    Environment = var.environment
    Purpose     = "appointment-reminders"
  }
}

resource "aws_sns_topic" "lab_results" {
  name              = "${local.name_prefix}-lab-results"
  kms_master_key_id = var.kms_main_key_arn

  tags = {
    Name        = "${local.name_prefix}-lab-results"
    Environment = var.environment
    Purpose     = "lab-result-notifications"
  }
}

resource "aws_sqs_queue" "billing_dlq" {
  name                      = "${local.name_prefix}-billing-dlq"
  message_retention_seconds = 1209600
  kms_master_key_id         = var.kms_main_key_arn

  tags = {
    Name        = "${local.name_prefix}-billing-dlq"
    Environment = var.environment
    Purpose     = "billing-dead-letter"
  }
}

resource "aws_sqs_queue" "billing" {
  name                       = "${local.name_prefix}-billing"
  visibility_timeout_seconds = 300
  message_retention_seconds  = 86400
  kms_master_key_id          = var.kms_main_key_arn

  redrive_policy = jsonencode({
    deadLetterTargetArn = aws_sqs_queue.billing_dlq.arn
    maxReceiveCount     = 3
  })

  tags = {
    Name        = "${local.name_prefix}-billing"
    Environment = var.environment
    Purpose     = "billing-claims-queue"
  }
}

resource "aws_sqs_queue" "hospital_integration_dlq" {
  name                      = "${local.name_prefix}-hospital-dlq"
  message_retention_seconds = 1209600
  kms_master_key_id         = var.kms_main_key_arn

  tags = {
    Name        = "${local.name_prefix}-hospital-dlq"
    Environment = var.environment
    Purpose     = "hospital-integration-dead-letter"
  }
}

resource "aws_sqs_queue" "hospital_integration" {
  name                       = "${local.name_prefix}-hospital-integration"
  visibility_timeout_seconds = 300
  message_retention_seconds  = 86400
  kms_master_key_id          = var.kms_main_key_arn

  redrive_policy = jsonencode({
    deadLetterTargetArn = aws_sqs_queue.hospital_integration_dlq.arn
    maxReceiveCount     = 3
  })

  tags = {
    Name        = "${local.name_prefix}-hospital-integration"
    Environment = var.environment
    Purpose     = "hospital-system-integration"
  }
}

resource "aws_sqs_queue" "audit_fifo_dlq" {
  name                      = "${local.name_prefix}-audit-dlq.fifo"
  fifo_queue                = true
  message_retention_seconds = 1209600
  kms_master_key_id         = var.kms_main_key_arn

  tags = {
    Name        = "${local.name_prefix}-audit-dlq"
    Environment = var.environment
  }
}

resource "aws_sqs_queue" "audit_fifo" {
  name                        = "${local.name_prefix}-audit.fifo"
  fifo_queue                  = true
  content_based_deduplication = true
  visibility_timeout_seconds  = 60
  kms_master_key_id           = var.kms_main_key_arn

  redrive_policy = jsonencode({
    deadLetterTargetArn = aws_sqs_queue.audit_fifo_dlq.arn
    maxReceiveCount     = 3
  })

  tags = {
    Name        = "${local.name_prefix}-audit-fifo"
    Environment = var.environment
    Purpose     = "ordered-audit-logging"
  }
}

resource "aws_security_group" "lambda" {
  name        = "${local.name_prefix}-lambda-sg"
  description = "Security group for emergency notification Lambda"
  vpc_id      = var.vpc_id

  egress {
    description = "Allow outbound for SNS and Secrets Manager API calls"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name        = "${local.name_prefix}-lambda-sg"
    Environment = var.environment
  }
}

data "archive_file" "emergency_lambda" {
  type        = "zip"
  output_path = "${path.module}/lambda/emergency.zip"

  source {
    content  = <<-EOT
      import boto3
      import json
      import os
      import logging
      from datetime import datetime

      logger = logging.getLogger()
      logger.setLevel(logging.INFO)

      sns = boto3.client('sns')
      dynamodb = boto3.resource('dynamodb')

      def lambda_handler(event, context):
          environment = os.environ['ENVIRONMENT']
          topic_arn = os.environ['EMERGENCY_TOPIC_ARN']
          table_name = os.environ['ALERTS_TABLE_NAME']

          alert_id = context.aws_request_id
          timestamp = datetime.utcnow().isoformat()

          try:
              sns.publish(
                  TopicArn=topic_arn,
                  Message=json.dumps({
                      'alert_id': alert_id,
                      'timestamp': timestamp,
                      'environment': environment,
                      'payload': event
                  }),
                  Subject='EMERGENCY ALERT - MediCare+',
                  MessageAttributes={
                      'severity': {
                          'DataType': 'String',
                          'StringValue': event.get('severity', 'HIGH')
                      }
                  }
              )

              table = dynamodb.Table(table_name)
              table.put_item(Item={
                  'alert_id': alert_id,
                  'timestamp': timestamp,
                  'status': 'SENT',
                  'payload': json.dumps(event),
                  'environment': environment
              })

              logger.info(f"Emergency alert {alert_id} sent successfully")
              return {'statusCode': 200, 'alert_id': alert_id}

          except Exception as e:
              logger.error(f"Failed to send emergency alert: {str(e)}")
              raise
    EOT
    filename = "emergency.py"
  }
}

resource "aws_lambda_function" "emergency" {
  filename         = data.archive_file.emergency_lambda.output_path
  function_name    = "${local.name_prefix}-emergency-notification"
  role             = var.lambda_role_arn
  handler          = "emergency.lambda_handler"
  runtime          = "python3.12"
  source_code_hash = data.archive_file.emergency_lambda.output_base64sha256
  timeout          = 30
  memory_size      = 256

  vpc_config {
    subnet_ids         = var.private_subnet_ids
    security_group_ids = [aws_security_group.lambda.id]
  }

  environment {
    variables = {
      ENVIRONMENT        = var.environment
      EMERGENCY_TOPIC_ARN = aws_sns_topic.emergency.arn
      ALERTS_TABLE_NAME  = "${local.name_prefix}-alerts"
    }
  }

  tags = {
    Name        = "${local.name_prefix}-emergency-notification"
    Environment = var.environment
    Purpose     = "emergency-alerts"
  }
}

resource "aws_cloudwatch_log_group" "lambda_emergency" {
  name              = "/aws/lambda/${local.name_prefix}-emergency-notification"
  retention_in_days = 90

  tags = {
    Name        = "${local.name_prefix}-emergency-logs"
    Environment = var.environment
  }
}

resource "aws_dynamodb_table" "alerts" {
  name         = "${local.name_prefix}-alerts"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "alert_id"
  range_key    = "timestamp"

  attribute {
    name = "alert_id"
    type = "S"
  }

  attribute {
    name = "timestamp"
    type = "S"
  }

  point_in_time_recovery {
    enabled = true
  }

  server_side_encryption {
    enabled     = true
    kms_key_arn = var.kms_main_key_arn
  }

  ttl {
    attribute_name = "ttl"
    enabled        = true
  }

  tags = {
    Name        = "${local.name_prefix}-alerts"
    Environment = var.environment
    Purpose     = "emergency-alert-log"
  }
}

resource "aws_cloudwatch_metric_alarm" "lambda_errors" {
  alarm_name          = "${local.name_prefix}-emergency-lambda-errors"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 1
  metric_name         = "Errors"
  namespace           = "AWS/Lambda"
  period              = 60
  statistic           = "Sum"
  threshold           = 0
  alarm_description   = "Emergency notification Lambda has errors"

  dimensions = {
    FunctionName = aws_lambda_function.emergency.function_name
  }

  tags = {
    Name        = "${local.name_prefix}-lambda-error-alarm"
    Environment = var.environment
  }
}