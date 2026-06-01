output "bucket_id" {
  value = aws_s3_bucket.bucket.id
}

output "cdn_url" {
  value       = var.cloudfront_enabled ? "https://cdn.${var.domain_name}" : null
  description = "Public CDN base URL for uploaded assets (no trailing slash)"
}
