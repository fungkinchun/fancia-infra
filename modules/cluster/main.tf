module "eks" {
  source                   = "../eks"
  project_name             = var.project_name
  environment              = var.environment
  vpc_id                   = var.vpc_id
  subnet_ids               = var.subnet_ids
  region                   = var.region
  principal_arn            = var.principal_arn
  route53_private_zone_arn = var.route53_private_zone_arn
  route53_public_zone_arn  = var.route53_public_zone_arn
}

module "eks_s3_loki_chunk" {
  source       = "../s3"
  bucket_name  = "${var.project_name}-loki-chunk-bucket"
  environment  = var.environment
  project_name = var.project_name
  region       = var.region
}

module "eks_s3_loki_ruler" {
  source       = "../s3"
  bucket_name  = "${var.project_name}-loki-ruler-bucket"
  environment  = var.environment
  project_name = var.project_name
  region       = var.region
}
