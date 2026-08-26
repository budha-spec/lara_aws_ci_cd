resource "aws_elastic_beanstalk_application" "laravel" {
    name = local.name
}

data "aws_elastic_beanstalk_solution_stack" "docker" {
  most_recent = true
  name_regex = "64bit Amazon Linux 2023.*running Docker"
}

resource "aws_elastic_beanstalk_environment" "prod" {
    name = "${local.name}-env"
    application = aws_elastic_beanstalk_application.laravel.name
    solution_stack_name = data.aws_elastic_beanstalk_solution_stack.docker.name

    lifecycle {
        ignore_changes = [
        version_label
        ]
    }
    
    setting {
        namespace = "aws:autoscaling:launchconfiguration"
        name      = "SecurityGroups"
        value     = aws_security_group.eb.id
    }


    setting {
        namespace ="aws:autoscaling:launchconfiguration"
        name ="IamInstanceProfile"
        value =aws_iam_instance_profile.eb.name
    }

    setting {
        namespace ="aws:elasticbeanstalk:environment"
        name ="EnvironmentType"
        value ="LoadBalanced"
    }

    setting {
        namespace ="aws:ec2:vpc"
        name ="VPCId"
        value =aws_vpc.main.id
    }

    setting {
        namespace ="aws:ec2:vpc"
        name = "Subnets"
        value = join(",",aws_subnet.public[*].id)
    }

    setting {
        namespace = "aws:ec2:vpc"
        name      = "AssociatePublicIpAddress"
        value     = "true"
    }

    setting {
      namespace ="aws:elasticbeanstalk:application:environment"
      name = "APP_URL"
      value = "http://${aws_elastic_beanstalk_environment.prod.cname}"
    }

    setting {
        namespace ="aws:elasticbeanstalk:application:environment"
        name ="DB_HOST"
        value =aws_db_instance.mysql.address
    }

    setting {
        namespace ="aws:elasticbeanstalk:application:environment"
        name ="DB_DATABASE"
        value =aws_db_instance.mysql.db_name
    }

    setting {
        namespace ="aws:elasticbeanstalk:application:environment"
        name ="DB_USERNAME"
        value =var.db_username
    }

    setting {
        namespace ="aws:elasticbeanstalk:application:environment"
        name ="DB_PASSWORD"
        value =var.db_password
    }

    setting {
        namespace = "aws:elasticbeanstalk:application:environment"
        name      = "APP_ENV"
        value     = "production"
    }

     setting {
        namespace = "aws:elasticbeanstalk:application:environment"
        name      = "APP_DEBUG"
        value     = "false"
    }

    setting {
        namespace = "aws:elasticbeanstalk:application:environment"
        name      = "APP_KEY"
        value     = var.app_key
    }

    setting {
        namespace = "aws:elasticbeanstalk:application:environment"
        name      = "DB_CONNECTION"
        value     = "mysql"
    }

    setting {
        namespace = "aws:elasticbeanstalk:application:environment"
        name      = "DB_PORT"
        value     = "3306"
    }
}