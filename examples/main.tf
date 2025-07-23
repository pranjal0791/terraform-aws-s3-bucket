resource "aws_kms_key" "bucket_encryption_key" {
  deletion_window_in_days = 30
}

resource "aws_kms_alias" "bucket_encryption_key_alias" {
  name          = "alias/${var.bucket_name}"
  target_key_id = aws_kms_key.bucket_encryption_key.key_id
}

resource "aws_s3_bucket" "bucket" {
  bucket = var.bucket_name

  lifecycle {
    prevent_destroy = true
  }
}

data "aws_iam_policy_document" "merged_bucket_policy" {
  source_policy_documents = concat(
    var.bucket_enforce_ssl ? [data.aws_iam_policy_document.enforce_ssl_policy_document.json] : [],
    var.bucket_policies
  )
}

resource "aws_s3_bucket_policy" "bucket_policy" {
  bucket = aws_s3_bucket.bucket.id
  policy = data.aws_iam_policy_document.merged_bucket_policy.json
}

data "aws_iam_policy_document" "kms_key_policy_document" {
  statement {
    principals {
      type        = "AWS"
      identifiers = ["arn:aws:iam::${var.account}:root"]
    }

    effect = "Allow"

    actions = ["kms:*"]

    resources = ["*"]
  }
}

data "aws_iam_policy_document" "merged_kms_key_policy" {
  source_policy_documents = concat(
    [data.aws_iam_policy_document.kms_key_policy_document.json],
    var.kms_key_policies
  )
}

resource "aws_kms_key_policy" "permission_mapping_kms_key_policy" {
  key_id = aws_kms_key.bucket_encryption_key.id
  policy = data.aws_iam_policy_document.merged_kms_key_policy.json
}


resource "aws_s3_bucket_server_side_encryption_configuration" "bucket_encryption" {
  bucket = aws_s3_bucket.bucket.id

  rule {
    apply_server_side_encryption_by_default {
      kms_master_key_id = aws_kms_key.bucket_encryption_key.arn
      sse_algorithm     = "aws:kms"
    }
  }
}

resource "aws_s3_bucket_versioning" "bucket_versioning" {
  count = var.bucket_versioning || var.bucket_object_lock ? 1 : 0

  bucket = aws_s3_bucket.bucket.id

  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_object_lock_configuration" "bucket_object_lock" {
  count = var.bucket_object_lock ? 1 : 0

  bucket = aws_s3_bucket.bucket.id

  rule {
    default_retention {
      mode = "COMPLIANCE"
      days = var.bucket_object_lock_default_retention
    }
  }
}

resource "aws_s3_bucket_logging" "bucket_logging" {
  count = var.bucket_server_access_logs_bucket != "" ? 1 : 0

  bucket = aws_s3_bucket.bucket.id

  target_bucket = var.bucket_server_access_logs_bucket
  target_prefix = var.bucket_server_access_logs_prefix
}

resource "aws_s3_bucket_inventory" "bucket_inventory" {
  count = var.bucket_inventory_arn != "" ? 1 : 0

  bucket = aws_s3_bucket.bucket.id

  name = "EntireBucketDaily"

  included_object_versions = "All"

  schedule {
    frequency = "Daily"
  }

  destination {
    bucket {
      format     = "CSV"
      bucket_arn = var.bucket_inventory_arn
      prefix     = "inventory/${var.bucket_name}"

    }
  }
}

resource "aws_s3_bucket_public_access_block" "bucket_block_public_access" {
  bucket = aws_s3_bucket.bucket.id

  block_public_acls       = var.bucket_public_access.block_public_acls
  block_public_policy     = var.bucket_public_access.block_public_policy
  ignore_public_acls      = var.bucket_public_access.ignore_public_acls
  restrict_public_buckets = var.bucket_public_access.restrict_public_buckets
}

data "aws_iam_policy_document" "enforce_ssl_policy_document" {
  statement {
    actions = [
      "s3:*",
    ]
    effect = "Deny"

    principals {
      type        = "*"
      identifiers = ["*"]
    }

    resources = [
      "${aws_s3_bucket.bucket.arn}/*"
    ]

    condition {
      test     = "Bool"
      variable = "aws:SecureTransport"
      values = [
        false,
      ]
    }
  }
}

resource "aws_s3_bucket_ownership_controls" "bucket_object_ownership" {
  bucket = aws_s3_bucket.bucket.id

  rule {
    object_ownership = var.bucket_object_ownership
  }
}

resource "aws_s3_bucket_cors_configuration" "bucket_cors_configuration" {
  for_each = {
    for i, rule in var.bucket_cors_configuration :
    i => rule
  }

  bucket = aws_s3_bucket.bucket.id

  cors_rule {
    allowed_headers = each.value.allowed_headers
    allowed_methods = each.value.allowed_methods
    allowed_origins = each.value.allowed_origins
    expose_headers  = each.value.expose_headers
    max_age_seconds = each.value.max_age_seconds
  }
}

resource "aws_s3_bucket_lifecycle_configuration" "bucket_lifecycle" {
  for_each = {
    for i, rule in var.bucket_lifecycle_rules :
    rule.id => rule
  }

  bucket = aws_s3_bucket.bucket.id

  rule {
    id = each.value.id
    expiration {
      date                         = each.value.expiration.date
      days                         = each.value.expiration.days
      expired_object_delete_marker = each.value.expiration.expired_object_delete_marker
    }

    filter {
      prefix = each.value.filter.prefix
    }

    status = "Enabled"
  }
}
