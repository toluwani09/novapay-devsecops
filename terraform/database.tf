resource "aws_security_group" "database" {
  name        = "${var.project_name}-${var.environment}-database-sg"
  description = "Allow PostgreSQL access only from NovaPay compute"
  vpc_id      = aws_vpc.novapay.id

  tags = {
    Name        = "${var.project_name}-${var.environment}-database-sg"
    Environment = var.environment
  }
}

resource "aws_vpc_security_group_ingress_rule" "database_from_compute" {
  security_group_id            = aws_security_group.database.id
  referenced_security_group_id = aws_security_group.compute.id
  from_port                    = 5432
  to_port                      = 5432
  ip_protocol                  = "tcp"
  description                  = "PostgreSQL access from NovaPay compute"
}

resource "aws_vpc_security_group_egress_rule" "database_egress" {
  security_group_id = aws_security_group.database.id
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "-1"
  description       = "Database outbound traffic"
}

resource "aws_db_subnet_group" "novapay" {
  name = "${var.project_name}-${var.environment}-db-subnet-group"

  subnet_ids = [
    aws_subnet.private.id,
    aws_subnet.private_2.id
  ]

  tags = {
    Name        = "${var.project_name}-${var.environment}-db-subnet-group"
    Environment = var.environment
  }
}

resource "aws_db_instance" "novapay" {
  identifier = "${var.project_name}-${var.environment}-db"

  engine         = "postgres"
  instance_class = "db.t3.micro"

  allocated_storage = 20
  storage_type      = "gp2"
  storage_encrypted = true

  db_name  = "novapay"
  username = "novapay_admin"

  manage_master_user_password = true

  db_subnet_group_name = aws_db_subnet_group.novapay.name

  vpc_security_group_ids = [
    aws_security_group.database.id
  ]

  publicly_accessible     = false
  skip_final_snapshot     = true
  deletion_protection     = false
  multi_az                = false
  backup_retention_period = 1

  tags = {
    Name        = "${var.project_name}-${var.environment}-database"
    Environment = var.environment
  }
}