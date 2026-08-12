resource "aws_security_group" "eb" {
  name        = "eb_sg"
  description = "Elastic beanstalk EC2"
  vpc_id      = aws_vpc.main.id

  ingress {
    from_port = 0
    to_port = 0
    protocol = "-1"
    cidr_blocks = [ "0.0.0.0/0" ]
  }
}


resource "aws_security_group" "rds" {
  name        = "rds"
  vpc_id      = aws_vpc.main.id

  ingress {
    from_port = 3306
    to_port = 3306
    protocol = "tcp"
    security_groups = [ aws_security_group.eb.id ]
  }

  egress {
    from_port = 0
    to_port = 0
    protocol = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.tag_name}-rds-sg"
    Environment = var.env
    Managed_By = var.managed_by
  }
}

