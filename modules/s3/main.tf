resource "aws_s3_bucket" "bucket" {
  bucket        = var.bucket_name
  force_destroy = true
}

resource "aws_s3_bucket_public_access_block" "bucket_public_access_block" {
  bucket                  = aws_s3_bucket.bucket.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_acm_certificate" "cdn" {
  provider          = aws.us_east_1
  count             = var.cloudfront_enabled ? 1 : 0
  domain_name       = "cdn.${var.domain_name}"
  validation_method = "DNS"

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_route53_record" "cdn_cert_validation" {
  for_each = var.cloudfront_enabled ? {
    for o in aws_acm_certificate.cdn[0].domain_validation_options : o.domain_name => {
      name   = o.resource_record_name
      record = o.resource_record_value
      type   = o.resource_record_type
    }
  } : {}

  allow_overwrite = true
  name            = each.value.name
  records         = [each.value.record]
  ttl             = 60
  type            = each.value.type
  zone_id         = var.public_zone_id
}

resource "aws_acm_certificate_validation" "cdn" {
  provider                = aws.us_east_1
  count                   = var.cloudfront_enabled ? 1 : 0
  certificate_arn         = aws_acm_certificate.cdn[0].arn
  validation_record_fqdns = [for record in aws_route53_record.cdn_cert_validation : record.fqdn]

  timeouts {
    create = "10m"
  }
}

resource "aws_s3_bucket_policy" "bucket_policy" {
  count  = var.cloudfront_enabled ? 1 : 0
  bucket = aws_s3_bucket.bucket.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "AllowCloudFrontServicePrincipalReadOnly"
        Effect = "Allow"
        Principal = {
          Service = "cloudfront.amazonaws.com"
        }
        Action   = "s3:GetObject"
        Resource = "${aws_s3_bucket.bucket.arn}/*"
        Condition = {
          StringEquals = {
            "AWS:SourceArn" = aws_cloudfront_distribution.s3_distribution[0].arn
          }
        }
      }
    ]
  })

  depends_on = [
    aws_s3_bucket_public_access_block.bucket_public_access_block,
    aws_cloudfront_distribution.s3_distribution,
  ]
}

resource "aws_s3_bucket_versioning" "bucket_policy_versioning" {
  bucket = aws_s3_bucket.bucket.id

  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "bucket_encryption" {
  bucket = aws_s3_bucket.bucket.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_cloudfront_origin_access_control" "s3_origin_access_control" {
  count                             = var.cloudfront_enabled ? 1 : 0
  name                              = "${aws_s3_bucket.bucket.id}-oac"
  description                       = "OAC for S3 bucket ${aws_s3_bucket.bucket.id}"
  origin_access_control_origin_type = "s3"
  signing_behavior                  = "always"
  signing_protocol                  = "sigv4"
}

resource "aws_cloudfront_distribution" "s3_distribution" {
  count = var.cloudfront_enabled ? 1 : 0

  origin {
    domain_name              = aws_s3_bucket.bucket.bucket_regional_domain_name
    origin_access_control_id = aws_cloudfront_origin_access_control.s3_origin_access_control[0].id
    origin_id                = "S3-${aws_s3_bucket.bucket.bucket}"
  }

  enabled         = true
  is_ipv6_enabled = true
  aliases         = ["cdn.${var.domain_name}"]

  default_cache_behavior {
    allowed_methods  = ["GET", "HEAD", "OPTIONS"]
    cached_methods   = ["GET", "HEAD"]
    target_origin_id = "S3-${aws_s3_bucket.bucket.bucket}"

    forwarded_values {
      query_string = false
      headers      = ["Origin", "Access-Control-Request-Headers", "Access-Control-Request-Method"]

      cookies {
        forward = "none"
      }
    }

    viewer_protocol_policy = "redirect-to-https"
  }

  viewer_certificate {
    acm_certificate_arn      = aws_acm_certificate_validation.cdn[0].certificate_arn
    ssl_support_method       = "sni_only"
    minimum_protocol_version = "TLSv1.2"
  }

  restrictions {
    geo_restriction {
      restriction_type = "none"
    }
  }

  depends_on = [aws_s3_bucket.bucket]
}

resource "aws_route53_record" "cdn" {
  count   = var.cloudfront_enabled ? 1 : 0
  zone_id = var.public_zone_id
  name    = "cdn"
  type    = "A"

  alias {
    name                   = aws_cloudfront_distribution.s3_distribution[0].domain_name
    zone_id                = aws_cloudfront_distribution.s3_distribution[0].hosted_zone_id
    evaluate_target_health = false
  }
}

resource "aws_route53_record" "cdn_ipv6" {
  count   = var.cloudfront_enabled ? 1 : 0
  zone_id = var.public_zone_id
  name    = "cdn"
  type    = "AAAA"

  alias {
    name                   = aws_cloudfront_distribution.s3_distribution[0].domain_name
    zone_id                = aws_cloudfront_distribution.s3_distribution[0].hosted_zone_id
    evaluate_target_health = false
  }
}
