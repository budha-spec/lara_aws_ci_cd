resource "aws_subnet" "public" {
  vpc_id     = aws_vpc.main.id
  count = 2
  cidr_block = cidrsubnet(var.vpc_cidr, 8, count.index)
  map_public_ip_on_launch = true

  tags = {
    Name = "${var.tag_name}-public-subnet-${count.index}"
    Environment = var.env
    Managed_By = var.managed_by
  }
}

resource "aws_subnet" "private" {
  vpc_id     = aws_vpc.main.id
  count = 2
  cidr_block = cidrsubnet(var.vpc_cidr, 8, count.index+10)

  tags = {
    Name = "${var.tag_name}-private-subnet-${count.index}"
    Environment = var.env
    Managed_By = var.managed_by
  }
}