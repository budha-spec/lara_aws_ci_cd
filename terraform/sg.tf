resource "aws_security_group" "eb" {
  name        = "${local.name}-eb-sg"
  description = "Elastic Beanstalk EC2"
  vpc_id      = aws_vpc.main.id

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_security_group" "rds" {
  name   = "${local.name}-rds-sg"
  vpc_id = aws_vpc.main.id

  ingress {
    description     = "MySQL from Elastic Beanstalk"
    from_port       = 3306
    to_port         = 3306
    protocol        = "tcp"

    security_groups = [
      aws_security_group.eb.id
    ]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

