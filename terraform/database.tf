################################################################################
# 5.1 Bonus: Managed Persistence Layer (RDS)
################################################################################

# Security Group for Databases (Allow EKS to connect)
resource "aws_security_group" "rds" {
  name        = "project-bedrock-rds-sg"
  description = "Allow inbound traffic from EKS"
  vpc_id      = module.vpc.vpc_id

  ingress {
    from_port       = 3306
    to_port         = 3306
    protocol        = "tcp"
    security_groups = [module.eks.node_security_group_id]
  }

  ingress {
    from_port       = 5432
    to_port         = 5432
    protocol        = "tcp"
    security_groups = [module.eks.node_security_group_id]
  }

  tags = {
    Project = "Bedrock"
  }
}

# Subnet Group
resource "aws_db_subnet_group" "default" {
  name       = "project-bedrock-db-subnet-group"
  subnet_ids = module.vpc.private_subnets

  tags = {
    Project = "Bedrock"
  }
}

# Generate random passwords
resource "random_password" "mysql_password" {
  length  = 16
  special = false
}

resource "random_password" "postgres_password" {
  length  = 16
  special = false
}

# 1. MySQL for Catalog Service
module "mysql_catalog" {
  source  = "terraform-aws-modules/rds/aws"
  version = "~> 6.0"

  identifier = "bedrock-catalog-db"

  engine               = "mysql"
  engine_version       = "8.0"
  family               = "mysql8.0"
  major_engine_version = "8.0"
  instance_class       = "db.t3.micro"

  allocated_storage     = 20
  max_allocated_storage = 100

  db_name  = "catalog_db"
  username = "catalog_user"
  port     = 3306

  password = random_password.mysql_password.result

  db_subnet_group_name   = aws_db_subnet_group.default.name
  vpc_security_group_ids = [aws_security_group.rds.id]

  # Disable deletion protection for student environment
  deletion_protection = false
  skip_final_snapshot = true
  manage_master_user_password = false

  tags = {
    Project = "Bedrock"
  }
}

# 2. PostgreSQL for Orders Service
module "postgres_orders" {
  source  = "terraform-aws-modules/rds/aws"
  version = "~> 6.0"

  identifier = "bedrock-orders-db"

  engine               = "postgres"
  engine_version       = "15"
  family               = "postgres15"
  major_engine_version = "15"
  instance_class       = "db.t3.micro"

  allocated_storage     = 20
  max_allocated_storage = 100

  db_name  = "orders_db"
  username = "orders_user"
  port     = 5432
  password = random_password.postgres_password.result

  db_subnet_group_name   = aws_db_subnet_group.default.name
  vpc_security_group_ids = [aws_security_group.rds.id]

  deletion_protection = false
  skip_final_snapshot = true
  manage_master_user_password = false

  tags = {
    Project = "Bedrock"
  }
}

# Store credentials in Kubernetes Secrets for the App to use
resource "kubernetes_secret_v1" "db_credentials" {
  metadata {
    name = "db-credentials"
    namespace = "retail-app"
  }

  data = {
    mysql_endpoint = module.mysql_catalog.db_instance_address
    mysql_password = random_password.mysql_password.result
    mysql_username = "catalog_user"
    
    postgres_endpoint = module.postgres_orders.db_instance_address
    postgres_password = random_password.postgres_password.result
    postgres_username = "orders_user"
  }
  
  depends_on = [kubernetes_namespace_v1.retail_app]
}
