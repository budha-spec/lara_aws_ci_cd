resource "aws_elastic_beanstalk_application" "laravel" {
  name    = var.tag_name
}

data "aws_elastic_beanstalk_solution_stack" "php" {
  most_recent = true
  name_regex = "64bit Amazon Linux 2023.*PHP 8.3"
}

resource "aws_elastic_beanstalk_environment" "eb_env" {
    name                = "${var.tag_name}-env"
    application         = aws_elastic_beanstalk_application.laravel.name
    solution_stack_name = data.aws_elastic_beanstalk_solution_stack.php
    
    setting {
        namespace = "aws:autoscaling:launchconfiguration"
        name      = "SecurityGroups"
        value     = aws_security_group.eb.id
    }

    setting {
        namespace = "aws:autoscaling:launchconfiguration"
        name      = "IamInstanceProfile"
        value     = aws_iam_instance_profile.eb_profile.name
    }

    setting {
        namespace = "aws:ec2:vpc"
        name      = "VPCId"
        value     = aws_vpc.main.id
    }

    setting {
        namespace = "aws:ec2:vpc"
        name      = "Subnets"
        value     = join(",", aws_subnet.public[*].id)
    }

    setting {
        namespace = "aws:elasticbeanstalk:application:environment"
        name = "DB_CONNECTION"
        value = "mysql"
    }

    setting {
        namespace = "aws:elasticbeanstalk:application:environment"
        name = "DB_PORT"
        value = "3306"
    }

    setting {
        namespace = "aws:elasticbeanstalk:application:environment"
        name = "DB_DATABASE"
        value = aws_db_instance.mysql.db_name
    }

    setting {
        namespace = "aws:elasticbeanstalk:application:environment"
        name = "DB_HOST"
        value = aws_db_instance.mysql.address
    }

    setting {
        namespace = "aws:elasticbeanstalk:application:environment"
        name = "DB_USERNAME"
        value = var.db_username
    }

    setting {
        namespace = "aws:elasticbeanstalk:application:environment"
        name = "DB_PASSWORD"
        value = var.db_password
    }
}