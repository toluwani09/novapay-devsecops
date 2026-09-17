resource "aws_security_group" "compute" {
  name        = "${var.project_name}-${var.environment}-compute-sg"
  description = "Security group for NovaPay compute"
  vpc_id      = aws_vpc.novapay.id

  tags = {
    Name        = "${var.project_name}-${var.environment}-compute-sg"
    Environment = var.environment
  }
}

resource "aws_vpc_security_group_ingress_rule" "application" {
  security_group_id = aws_security_group.compute.id
  cidr_ipv4         = "0.0.0.0/0"
  from_port         = 8000
  to_port           = 8000
  ip_protocol       = "tcp"
  description       = "NovaPay application access"
}

resource "aws_vpc_security_group_egress_rule" "compute_egress" {
  security_group_id = aws_security_group.compute.id
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "-1"
  description       = "NovaPay compute outbound access"
}

resource "aws_instance" "novapay" {
  ami                    = data.aws_ami.amazon_linux.id
  instance_type          = "t3.micro"
  subnet_id              = aws_subnet.public.id
  vpc_security_group_ids = [aws_security_group.compute.id]

  iam_instance_profile = aws_iam_instance_profile.novapay.name

  user_data = <<-EOF
              #!/bin/bash
              dnf install -y docker
              systemctl enable docker
              systemctl start docker
              EOF

  tags = {
    Name        = "${var.project_name}-${var.environment}-compute"
    Environment = var.environment
  }
}

data "aws_ami" "amazon_linux" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["al2023-ami-2023.*-x86_64"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}