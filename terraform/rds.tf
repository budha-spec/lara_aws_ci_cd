resource "aws_db_subnet_group" "mysql" {
  name = "${local.name}-db-subnet"
  subnet_ids =aws_subnet.private[*].id
}

resource "aws_db_instance" "mysql" {
  identifier ="${local.name}-mysql"
  engine ="mysql"
  engine_version ="8.0"
  instance_class ="db.t3.micro"
  allocated_storage =20
  db_name ="laravel"
  username =var.db_username
  password =var.db_password
  db_subnet_group_name =aws_db_subnet_group.mysql.name
  skip_final_snapshot =true

  vpc_security_group_ids = [
    aws_security_group.rds.id
  ]
}