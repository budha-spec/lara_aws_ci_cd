resource "aws_cloudwatch_log_group" "eb" {
    name ="/elasticbeanstalk/${local.name}"
    retention_in_days =30
}