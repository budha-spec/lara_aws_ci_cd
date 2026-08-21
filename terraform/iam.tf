resource "aws_iam_role" "eb_role" {
    name = "aws-elasticbeanstalk-lara-app-prod-eb-role"
    assume_role_policy = jsonencode({
        Version="2012-10-17"
        Statement=[{
            Effect="Allow"
            Principal={
                Service="ec2.amazonaws.com"
            }
            Action="sts:AssumeRole"
        }]
    })
}

resource "aws_ecr_repository" "laravel" {
  name                 = "${local.name}-laravel"
  image_tag_mutability = "IMMUTABLE"

  image_scanning_configuration {
    scan_on_push = true
  }

  encryption_configuration {
    encryption_type = "AES256"
  }
}


resource "aws_iam_role_policy" "eb_ecr" {
  role = aws_iam_role.eb_role.id

  policy = jsonencode({
    Version = "2012-10-17"

    Statement = [
      {
        Effect = "Allow"

        Action = [
          "ecr:GetAuthorizationToken"
        ]

        Resource = "*"
      },
      {
        Effect = "Allow"

        Action = [
          "ecr:BatchCheckLayerAvailability",
          "ecr:GetDownloadUrlForLayer",
          "ecr:BatchGetImage"
        ]

        Resource = aws_ecr_repository.laravel.arn
      }
    ]
  })
}



resource "aws_iam_role_policy_attachment" "eb_attach" {
    role = aws_iam_role.eb_role.name
    policy_arn = "arn:aws:iam::aws:policy/AWSElasticBeanstalkWebTier"
}


resource "aws_iam_instance_profile" "eb" {
    name="${local.name}-profile"
    role = aws_iam_role.eb_role.name
}