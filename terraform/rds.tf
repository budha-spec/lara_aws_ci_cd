resource "aws_db_subnet_group" "subnet_group" {
  name       = "subnet_group"
  subnet_ids = aws_subnet.private[*].id

  tags = {
    Name = "${var.tag_name}-subnet-group"
    Environment = var.env
    Managed_By = var.managed_by
  }
}

resource "aws_db_instance" "mysql" {
  allocated_storage    = 20
  db_name              = var.db_name
  engine               = "mysql"
  engine_version       = "8.0"
  instance_class       = "db.t3.micro"
  username             = var.db_username
  password             = var.db_password
  db_subnet_group_name = aws_db_subnet_group.subnet_group.name
  vpc_security_group_ids = [ aws_security_group.rds.id ]
  skip_final_snapshot  = true
}