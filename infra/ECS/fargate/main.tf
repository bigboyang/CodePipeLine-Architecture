data "aws_vpc" "default" {
  default = true
}

resource "aws_ecs_cluster" "example" {
  name = "my-cluster"
}

resource "aws_ecs_cluster_capacity_providers" "example" {
  cluster_name = aws_ecs_cluster.example.name

  capacity_providers = ["FARGATE"]

  default_capacity_provider_strategy {
    base              = 1
    weight            = 100
    capacity_provider = "FARGATE"
  }
}
# resource "aws_ecs_task_definition" "example" {
#   family = "example-task-definition"
#   requires_compatibilities = ["FARGATE"]

#   container_definitions = jsonencode([
#     {
#       name  = "example-container"
#       image = "038795414938.dkr.ecr.ap-northeast-2.amazonaws.com/demo:1.0.0"
#       command         = ["sh", "-c", "~/deploy/scripts/run_process.sh"]
#       cpu   = 256
#       memory = 512
#       essential = true
#       portMappings = [
#         {
#           containerPort = 8080
#           hostPort      = 8080
#           protocol      = "tcp"
#         }
#       ]
#       environment = [
#         {
#           name  = "AWS_REGION"
#           value = "ap-northeast-2"
#         }
#       ]
#     }
#   ])

#   network_mode = "awsvpc"
#   cpu = "256"
#   memory = "512"
#   execution_role_arn = aws_iam_role.ecs_task.arn
#   task_role_arn = aws_iam_role.ecs_task.arn
# }

resource "aws_ecs_task_definition" "example" {
  family                   = "nginx"
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]

  container_definitions = jsonencode([
    {
      name        = "example-container"
      image       = "nginx:latest"

      essential   = true
      portMappings = [
        {
          containerPort = 80
          hostPort      = 80
          protocol      = "tcp"
        }
      ]
    }
  ])
  cpu = "256"
  memory = "512"
  execution_role_arn = aws_iam_role.ecs_task.arn
  task_role_arn = aws_iam_role.ecs_task.arn
}

resource "aws_lb" "example" {
  name               = "example-lb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [local.default_sg_id]
  subnets            = local.public_subnet_ids
}

resource "aws_lb_listener" "example" {
  load_balancer_arn = aws_lb.example.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    target_group_arn = aws_lb_target_group.example.arn
    type             = "forward"
  }

  depends_on = [aws_lb_target_group.example]

}

resource "aws_ecs_service" "example" {
  name             = "example-service"
  cluster          = aws_ecs_cluster.example.id
  task_definition  = aws_ecs_task_definition.example.arn
  desired_count    = 1
  platform_version = "LATEST"
  launch_type      = "FARGATE"

  load_balancer {
    target_group_arn = aws_lb_target_group.example.arn
    container_name   = "example-container"
    container_port   = 80
  }

  network_configuration {
    subnets         = local.public_subnet_ids
    security_groups = [local.default_sg_id]
    assign_public_ip = false
  }
  
  depends_on = [
    aws_ecs_task_definition.example,
    aws_lb.example
  ]
}


resource "aws_iam_role" "ecs_task" {
  name = "example-ecs-task-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ecs-tasks.amazonaws.com"
        }
      }
    ]
  })
}

resource "aws_lb_target_group" "example" {
  name_prefix = "ecs-tg"

  port        = 80
  protocol    = "HTTP"
  vpc_id      = local.vpc_id
  # vpc_id      = data.aws_vpc.default.id
  target_type = "ip" 

  health_check {
    enabled             = true
    interval            = 300
    path                = "/"
    timeout             = 60
    matcher             = "200"
    healthy_threshold   = 5
    unhealthy_threshold = 5
  }

  lifecycle {
    create_before_destroy = true
  }

  depends_on = [aws_lb.example]
}

output "ecs_service_url" {
  value = "${aws_lb_target_group.example.arn}"
}
