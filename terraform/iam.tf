resource "aws_iam_role" "eb_role" {
    name = "${local.name}-eb-role"
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


resource "aws_iam_role_policy_attachment" "eb_attach" {
    role = aws_iam_role.eb_role.name
    policy_arn = "arn:aws:iam::aws:policy/AWSElasticBeanstalkWebTier"
}


resource "aws_iam_instance_profile" "eb" {
    name="${local.name}-profile"
    role = aws_iam_role.eb_role.name
}