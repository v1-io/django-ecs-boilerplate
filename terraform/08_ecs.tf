resource "aws_ecs_cluster" "stage" {
  name = "${var.ecs_cluster_name}-cluster"
}

resource "aws_launch_configuration" "ecs" {
  name                        = "${var.ecs_cluster_name}-cluster"
  image_id                    = lookup(var.amis, var.region)
  instance_type               = var.instance_type
  security_groups             = [aws_security_group.ecs.id]
  iam_instance_profile        = aws_iam_instance_profile.ecs.name
  key_name                    = aws_key_pair.stage.key_name
  associate_public_ip_address = true
  user_data                   = <<EOF
    #!/bin/bash
    echo ECS_CLUSTER=${var.ecs_cluster_name}-cluster >> /etc/ecs/ecs.config
  EOF
}

resource "aws_ecs_task_definition" "app" {
  family                = "canary"
  execution_role_arn    = aws_iam_role.ecs-execution-role.arn
  task_role_arn         = aws_iam_role.ecs-execution-role.arn
  depends_on            = [aws_db_instance.stage]

  container_definitions = jsonencode([
    {
      name              = "canary"
      image             = var.docker_image_url_django
      essential         = true
      cpu               = 256
      memory            = 256
      links             = []
      portMappings      = [
        {
          containerPort  = 8000
          hostPort        = 8000
          protocol        = "tcp"
        }
      ]
      command           = ["gunicorn", "-w", "3", "-b", ":8000", "canary.wsgi:application"]
      environment       = [
        {
          name  = "RDS_DB_NAME"
          value = var.rds_db_name
        },
        {
          name  = "RDS_USERNAME"
          value = var.rds_username
        },
        {
          name  = "RDS_PASSWORD"
          value = var.rds_password
        },
        {
          name  = "RDS_HOSTNAME"
          value = aws_db_instance.stage.address
        },
        {
          name  = "RDS_PORT"
          value = "5432"
        }
      ]
      logConfiguration  = {
        logDriver = "awslogs"
        options = {
          awslogs-group         = "/ecs/canary"
          awslogs-region        = var.region
          awslogs-stream-prefix = "canary-log-stream"
        }
      }
    },
    {
      name              = "migrate"
      image             = var.docker_image_url_django
      essential         = false
      cpu               = 128
      memory            = 128
      links             = []
      command           = ["python", "manage.py", "migrate", "--no-input"]
      environment       = [
        {
          name  = "RDS_DB_NAME"
          value = var.rds_db_name
        },
        {
          name  = "RDS_USERNAME"
          value = var.rds_username
        },
        {
          name  = "RDS_PASSWORD"
          value = var.rds_password
        },
        {
          name  = "RDS_HOSTNAME"
          value = aws_db_instance.stage.address
        },
        {
          name  = "RDS_PORT"
          value = "5432"
        }
      ]
      logConfiguration  = {
        logDriver = "awslogs"
        options = {
          awslogs-group         = "/ecs/migrate"
          awslogs-region        = var.region
          awslogs-stream-prefix = "migrate"
        }
      }
    },
    {
      name              = "nginx"
      image             = var.docker_image_url_nginx
      essential         = true
      cpu               = 256
      memory            = 256
      links             = ["canary"]
      portMappings      = [
        {
          containerPort  = 80
          hostPort        = 80
          protocol        = "tcp"
        }
      ]
      logConfiguration  = {
        logDriver = "awslogs"
        options = {
          awslogs-group         = "/ecs/nginx"
          awslogs-region        = var.region
          awslogs-stream-prefix = "nginx-log-stream"
        }
      }
    }
  ])
}

resource "aws_ecs_service" "stage" {
  name            = "${var.ecs_cluster_name}-service"
  cluster         = aws_ecs_cluster.stage.id
  task_definition = aws_ecs_task_definition.app.arn
  launch_type     = "EC2" 

  deployment_maximum_percent         = 200
  deployment_minimum_healthy_percent = 0
  desired_count   = var.app_count
  depends_on      = [aws_alb_listener.ecs-alb-http-listener, aws_iam_role_policy.ecs-service-role-policy]


  load_balancer {
    target_group_arn = aws_alb_target_group.default-target-group.arn
    container_name   = "nginx"
    container_port   = 80
  }
}