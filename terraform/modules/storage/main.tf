locals {
  name_prefix = "${var.project_name}-${var.environment}"
}

resource "aws_s3_bucket" "imaging" {
  bucket = "${local.name_prefix}-imaging"

  tags = {
    Name        = "${local.name_prefix}-imaging"
    Environment = var.environment
    Purpose     = "medical-imaging"
    Sensitivity = "high"
  }
}

resource "aws_s3_bucket_versioning" "imaging" {
  bucket = aws_s3_bucket.imaging.id

  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "imaging" {
  bucket = aws_s3_bucket.imaging.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm     = "aws:kms"
      kms_master_key_id = var.kms_s3_key_arn
    }
    bucket_key_enabled = true
  }
}

resource "aws_s3_bucket_public_access_block" "imaging" {
  bucket = aws_s3_bucket.imaging.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_lifecycle_configuration" "imaging" {
  bucket = aws_s3_bucket.imaging.id

  rule {
    id     = "imaging-lifecycle"
    status = "Enabled"

    transition {
      days          = var.imaging_lifecycle_days
      storage_class = "GLACIER"
    }

    noncurrent_version_transition {
      noncurrent_days = 30
      storage_class   = "GLACIER"
    }

    noncurrent_version_expiration {
      noncurrent_days = 365
    }
  }
}

resource "aws_s3_bucket_cors_configuration" "imaging" {
  bucket = aws_s3_bucket.imaging.id

  cors_rule {
    allowed_headers = ["Authorization", "Content-Type"]
    allowed_methods = ["GET", "PUT"]
    allowed_origins = ["*"]
    expose_headers  = ["ETag"]
    max_age_seconds = 900
  }
}

resource "aws_s3_bucket" "documents" {
  bucket = "${local.name_prefix}-documents"

  tags = {
    Name        = "${local.name_prefix}-documents"
    Environment = var.environment
    Purpose     = "patient-documents"
    Sensitivity = "high"
  }
}

resource "aws_s3_bucket_versioning" "documents" {
  bucket = aws_s3_bucket.documents.id

  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "documents" {
  bucket = aws_s3_bucket.documents.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm     = "aws:kms"
      kms_master_key_id = var.kms_s3_key_arn
    }
    bucket_key_enabled = true
  }
}

resource "aws_s3_bucket_public_access_block" "documents" {
  bucket = aws_s3_bucket.documents.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_lifecycle_configuration" "documents" {
  bucket = aws_s3_bucket.documents.id

  rule {
    id     = "documents-lifecycle"
    status = "Enabled"

    transition {
      days          = 180
      storage_class = "STANDARD_IA"
    }

    transition {
      days          = 365
      storage_class = "GLACIER"
    }

    noncurrent_version_expiration {
      noncurrent_days = 730
    }
  }
}



resource "aws_s3_bucket" "audit_logs" {
  bucket = "${local.name_prefix}-audit-logs"

  tags = {
    Name        = "${local.name_prefix}-audit-logs"
    Environment = var.environment
    Purpose     = "compliance-audit"
    Sensitivity = "high"
    Retention   = "7-years"
  }
}

resource "aws_s3_bucket_versioning" "audit_logs" {
  bucket = aws_s3_bucket.audit_logs.id

  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "audit_logs" {
  bucket = aws_s3_bucket.audit_logs.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm     = "aws:kms"
      kms_master_key_id = var.kms_s3_key_arn
    }
    bucket_key_enabled = true
  }
}

resource "aws_s3_bucket_public_access_block" "audit_logs" {
  bucket = aws_s3_bucket.audit_logs.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_lifecycle_configuration" "audit_logs" {
  bucket = aws_s3_bucket.audit_logs.id

  rule {
    id     = "audit-retention"
    status = "Enabled"

    transition {
      days          = 90
      storage_class = "STANDARD_IA"
    }

    transition {
      days          = 365
      storage_class = "GLACIER"
    }

    expiration {
      days = 2555
    }
  }
}

resource "aws_s3_bucket_object_lock_configuration" "audit_logs" {
  bucket = aws_s3_bucket.audit_logs.id

  rule {
    default_retention {
      mode = "COMPLIANCE"
      days = 2555
    }
  }

  depends_on = [aws_s3_bucket_versioning.audit_logs]
}