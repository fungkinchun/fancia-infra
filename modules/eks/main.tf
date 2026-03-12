data "aws_caller_identity" "current" {}

data "aws_iam_role" "codebuild_role" {
  name = "${var.project_name}-infra-codebuild-role"
}

resource "random_id" "kms_suffix" {
  byte_length = 4
}

module "eks_kms" {
  source  = "terraform-aws-modules/kms/aws"
  version = "~> 2.0"

  description = "KMS key for EKS ${var.project_name}-${var.environment} secrets envelope encryption"

  key_usage                = "ENCRYPT_DECRYPT"
  customer_master_key_spec = "SYMMETRIC_DEFAULT"
  enable_key_rotation      = true

  key_administrators = [
    var.principal_arn
  ]

  key_users = []

  key_service_users = [
    var.principal_arn
  ]

  aliases_use_name_prefix = true
}

module "eks" {
  source                                   = "terraform-aws-modules/eks/aws"
  version                                  = "~> 21.0"
  name                                     = "${var.project_name}-${var.environment}-eks"
  kubernetes_version                       = "1.33"
  vpc_id                                   = var.vpc_id
  subnet_ids                               = var.subnet_ids
  endpoint_public_access                   = true
  enable_cluster_creator_admin_permissions = true
  authentication_mode                      = "API_AND_CONFIG_MAP"
  iam_role_name                            = "${var.project_name}-${var.environment}-eks-cluster-role"

  compute_config = {
    enabled    = true
    node_pools = ["general-purpose"]
  }

  create_kms_key = false

  encryption_config = {
    resources        = ["secrets"]
    provider_key_arn = module.eks_kms.key_arn
  }

  depends_on = [module.eks_kms]
}

resource "aws_eks_access_entry" "main" {
  cluster_name  = module.eks.cluster_name
  principal_arn = var.principal_arn
  type          = "STANDARD"
}

resource "aws_eks_access_policy_association" "main" {
  cluster_name  = module.eks.cluster_name
  policy_arn    = "arn:aws:eks::aws:cluster-access-policy/AmazonEKSClusterAdminPolicy"
  principal_arn = var.principal_arn

  access_scope {
    type = "cluster"
  }
}

provider "kubernetes" {
  host                   = module.eks.cluster_endpoint
  cluster_ca_certificate = base64decode(module.eks.cluster_certificate_authority_data)

  exec {
    api_version = "client.authentication.k8s.io/v1beta1"
    command     = "aws"
    args = [
      "eks",
      "get-token",
      "--cluster-name",
      module.eks.cluster_name,
      "--region",
      var.region,
      "--output",
      "json"
    ]
  }
}

locals {
  oidc_issuer_url   = trimprefix(module.eks.cluster_oidc_issuer_url, "https://")
  oidc_provider_arn = module.eks.oidc_provider_arn
}

resource "aws_iam_role" "pod_role" {
  name                  = "${var.project_name}-${var.environment}-pod-role"
  force_detach_policies = true

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Federated = local.oidc_provider_arn
        }
        Action = "sts:AssumeRoleWithWebIdentity"
        Condition = {
          StringEquals = {
            "${local.oidc_issuer_url}:aud" = "sts.amazonaws.com"
            "${local.oidc_issuer_url}:sub" = [
              "system:serviceaccount:${kubernetes_namespace.namespace.metadata[0].name}:${var.project_name}-sa",
              "system:serviceaccount:${kubernetes_namespace.namespace.metadata[0].name}:external-secrets",
              "system:serviceaccount:${kubernetes_namespace.namespace.metadata[0].name}:aws-privateca-issuer"
            ]
          }
        }
      }
    ]
  })

  depends_on = [kubernetes_namespace.namespace]
}

resource "aws_iam_role_policy" "pod_role_policy" {
  name = "eks-pod-role-policy"
  role = aws_iam_role.pod_role.id

  policy = jsonencode({
    "Version" : "2012-10-17",
    "Statement" : [
      {
        "Effect" : "Allow",
        "Action" : "sts:GetCallerIdentity",
        "Resource" : "*"
      },
      {
        "Sid" : "AllowGlobalList",
        "Effect" : "Allow",
        "Action" : [
          "secretsmanager:ListSecrets"
        ],
        "Resource" : "*"
      },
      {
        "Sid" : "AllowScopedRead",
        "Effect" : "Allow",
        "Action" : [
          "secretsmanager:GetSecretValue",
          "secretsmanager:DescribeSecret",
          "secretsmanager:ListSecretVersionIds"
        ],
        "Resource" : "arn:aws:secretsmanager:${var.region}:*:secret:*"
      },
      {
        "Effect" : "Allow",
        "Action" : [
          "acm-pca:GetCertificate",
          "acm-pca:IssueCertificate",
          "acm-pca:DescribeCertificateAuthority"
        ],
        "Resource" : "*"
      }
    ]
  })
}

resource "kubernetes_namespace" "namespace" {
  metadata {
    name = "${var.project_name}-${var.environment}"
  }
  depends_on = [module.eks]
}

resource "kubernetes_service_account" "irsa_sa" {
  metadata {
    name      = "${var.project_name}-sa"
    namespace = kubernetes_namespace.namespace.metadata[0].name

    annotations = {
      "eks.amazonaws.com/role-arn"               = aws_iam_role.pod_role.arn
      "eks.amazonaws.com/sts-regional-endpoints" = "true"
    }
  }

  depends_on = [kubernetes_namespace.namespace]
}

resource "aws_iam_role" "alb_controller" {
  name                  = "${var.project_name}-${var.environment}-alb-controller-role"
  force_detach_policies = true

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Federated = local.oidc_provider_arn
        }
        Action = "sts:AssumeRoleWithWebIdentity"
        Condition = {
          StringEquals = {
            "${local.oidc_issuer_url}:aud" = "sts.amazonaws.com"
            "${local.oidc_issuer_url}:sub" = "system:serviceaccount:${kubernetes_namespace.namespace.metadata[0].name}:aws-load-balancer-controller"
          }
        }
      }
    ]
  })

  depends_on = [module.eks]
}

resource "aws_iam_policy" "alb_controller_policy" {
  name   = "alb-controller-policy"
  policy = file("${path.module}/alb-controller-iam-policy.json")
}

resource "aws_iam_role_policy_attachment" "alb_controller_policy_attachment" {
  role       = aws_iam_role.alb_controller.name
  policy_arn = aws_iam_policy.alb_controller_policy.arn
}

output "cluster_endpoint" {
  value = module.eks.cluster_endpoint
}

output "cluster_ca_certificate" {
  value = module.eks.cluster_certificate_authority_data
}

output "cluster_name" {
  value = module.eks.cluster_name
}
