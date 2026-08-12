resource "aws_iam_role" "eb_role" {
  name = "eb_role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
      },
    ]
  })

  tags = {
    Name = "${var.tag_name}-eb-role"
    Environment = var.env
    Managed_By = var.managed_by
  }
}

resource "aws_iam_role_policy_attachment" "attach_eb_role_policy" {
  role       = aws_iam_role.eb_role.name
  policy_arn = "arn:aws:iam::aws:policy/AWSElasticBeanstalkWebTier"
}

resource "aws_iam_instance_profile" "eb_profile" {
  name = "eb_profile"
  role = aws_iam_role.eb_role.name
}