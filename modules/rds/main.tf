resource "aws_security_group" "rds" {
  name        = "${var.rds_id}-rds-sg"
  description = "Security group for RDS PostgreSQL"
  vpc_id      = var.vpc_id

  ingress {
    description = "PostgreSQL access"
    from_port   = 5432
    to_port     = 5432
    protocol    = "tcp"
    cidr_blocks = var.allowed_cidr_blocks
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.rds_id}-rds-sg"
  }
}

module "rds" {
  source = "terraform-aws-modules/rds/aws"

  identifier = var.rds_id

  engine = "postgres"
  family = "postgres17"

  instance_class    = var.instance_class
  allocated_storage = var.allocated_storage
  storage_type      = "gp3"
  storage_encrypted = true

  db_name                     = var.db_name
  username                    = var.project_name
  manage_master_user_password = true

  port = 5432

  multi_az               = false
  publicly_accessible    = var.environment == "prod" ? false : true
  vpc_security_group_ids = [aws_security_group.rds.id]
  db_subnet_group_name   = var.db_subnet_group_name

  skip_final_snapshot = true

  create_db_parameter_group = true
  parameters = [
    {
      name  = "log_connections"
      value = "1"
    },
    {
      name  = "log_disconnections"
      value = "1"
    }
  ]

  tags = {
    Environment = "dev"
    Terraform   = "true"
  }
}

resource "aws_route53_record" "rds_cname" {
  zone_id = var.zone_id
  name    = "${var.repo_name}-rds"
  type    = "CNAME"
  ttl     = 60

  records = [module.rds.db_instance_address]
}

data "aws_secretsmanager_secret" "rds_master_user_secret" {
  arn = module.rds.db_instance_master_user_secret_arn
}

output "rds" {
  value = module.rds
}

output "rds_secret_arn" {
  value = module.rds.db_instance_master_user_secret_arn
}

output "rds_secret_name" {
  value = data.aws_secretsmanager_secret.rds_master_user_secret.name
}
