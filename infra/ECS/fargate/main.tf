
# VPC
resource "aws_vpc" "example" {
  cidr_block = "10.0.0.0/16"
  tags = {
    Name = "example-vpc"
  }
}

resource "aws_security_group" "example" {
  name_prefix = "example-sg-"

  ingress {
    description = "Allow HTTP"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "Allow HTTPS"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "Allow application traffic"
    from_port   = 8080
    to_port     = 8080
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  vpc_id = aws_vpc.example.id
}

# Public subnet
resource "aws_subnet" "public" {
  vpc_id            = aws_vpc.example.id
  cidr_block        = "10.0.1.0/24"
  availability_zone = "ap-northeast-2a"

  tags = {
    Name = "public"
  }
}

# Public subnet
resource "aws_subnet" "public2" {
  vpc_id            = aws_vpc.example.id
  cidr_block        = "10.0.5.0/24"
  availability_zone = "ap-northeast-2b"

  tags = {
    Name = "public2"
  }
}

# Private subnet
resource "aws_subnet" "private" {
  vpc_id            = aws_vpc.example.id
  cidr_block        = "10.0.2.0/24"
  availability_zone = "ap-northeast-2a"

  tags = {
    Name = "private"
  }
}

# Internet Gateway
resource "aws_internet_gateway" "example" {
  vpc_id = aws_vpc.example.id

  tags = {
    Name = "example-igw"
  }
}

# NAT Gateway
resource "aws_eip" "nat" {
  vpc = true
}

resource "aws_nat_gateway" "example" {
  allocation_id = aws_eip.nat.id
  subnet_id     = aws_subnet.public.id

  tags = {
    Name = "example-nat-gateway"
  }
}

# Route table for public subnet
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.example.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.example.id
  }

  tags = {
    Name = "public"
  }
}

# Route table for private subnet
resource "aws_route_table" "private" {
  vpc_id = aws_vpc.example.id

  route {
    cidr_block = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.example.id
  }

  tags = {
    Name = "private"
  }
}

# Associate public subnet with public route table
resource "aws_route_table_association" "public" {
  subnet_id      = aws_subnet.public.id
  route_table_id = aws_route_table.public.id
}

# Associate public subnet with public route table
resource "aws_route_table_association" "public2" {
  subnet_id      = aws_subnet.public2.id
  route_table_id = aws_route_table.public.id
}


# Associate private subnet with private route table
resource "aws_route_table_association" "private" {
  subnet_id      = aws_subnet.private.id
  route_table_id = aws_route_table.private.id
}

# Load Balancer

resource "aws_lb" "example" {
  name               = "example-lb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.example.id]
  subnets            = [aws_subnet.public.id, aws_subnet.public2.id]

}

# 80 리스너 생성
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

# 8080 리스너 생성
resource "aws_lb_listener" "example2" {
  load_balancer_arn = aws_lb.example.arn
  port              = 8080
  protocol          = "HTTP"

  default_action {
    target_group_arn = aws_lb_target_group.example2.arn
    type             = "forward"
  }
  depends_on = [aws_lb_target_group.example2]
}

# 80 타겟그룹 생성
resource "aws_lb_target_group" "example" {
  name_prefix = "ecs-tg"

  port        = 80
  protocol    = "HTTP"
  vpc_id      = aws_vpc.example.id
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

# 8080 타겟그룹 생성
resource "aws_lb_target_group" "example2" {
  name_prefix = "ecstg2"

  port        = 8080
  protocol    = "HTTP"
  vpc_id      = aws_vpc.example.id
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



# ECS
# cluster
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

# Service
resource "aws_ecs_service" "example" {
  name             = "example-service"
  cluster          = aws_ecs_cluster.example.id
  task_definition  = aws_ecs_task_definition.example.arn
  desired_count    = 1
  platform_version = "LATEST"
  # launch_type      = "FARGATE"

  capacity_provider_strategy {
    capacity_provider = "FARGATE"
    weight            = 50
    base              = 1
  }

  load_balancer {
    target_group_arn = aws_lb_target_group.example.arn
    container_name   = "example-container"
    container_port   = 80
  }

  network_configuration {
    subnets         = [aws_subnet.private.id]
    security_groups = [aws_security_group.example.id]
    assign_public_ip = true
  }
  
  depends_on = [
    aws_ecs_task_definition.example,
    aws_lb.example
  ] 
}

# service 2
resource "aws_ecs_service" "example2" {
  name             = "example-service-2"
  cluster          = aws_ecs_cluster.example.id
  task_definition  = aws_ecs_task_definition.example2.arn
  desired_count    = 1
  platform_version = "LATEST"

  capacity_provider_strategy {
    capacity_provider = "FARGATE"
    weight            = 50
    base              = 1
  }

  load_balancer {
    target_group_arn = aws_lb_target_group.example2.arn
    container_name   = "log-example-container"
    container_port   = 8080
  }

  network_configuration {
    subnets         = [aws_subnet.private.id]
    security_groups = [aws_security_group.example.id]
    assign_public_ip = true
  }
  
  depends_on = [
    aws_ecs_task_definition.example2,
    aws_lb.example
  ] 
}


# Task Definition
resource "aws_ecs_task_definition" "example" {
  family                   = "nginx"
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]

  container_definitions = jsonencode([
    {
      name        = "example-container"
      image       = "nginx:latest"
      essential   = true

      log_configuration = {
        log_driver = "awslogs"
        options    = {
          "awslogs-group"         = "/ecs/myapp"
          "awslogs-region"        = "ap-northeast-2"
          "awslogs-stream-prefix" = "ecs"
        }
      }
      
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


resource "aws_ecs_task_definition" "example2" {
  family                   = "my-task"
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]

  container_definitions = jsonencode([
    {
      name  = "log-example-container"
      image = "amazon/awslogs:latest"

      log_configuration = {
        log_driver = "awslogs"
        options = {
          "awslogs-region"        = "ap-northeast-2"
          "awslogs-group"         = "my-log-group"
          "awslogs-stream-prefix" = "my-stream-prefix"
        }
      }

      portMappings = [
        {
          containerPort = 8080
          hostPort      = 8080
          protocol      = "tcp"
        }
      ]

      essential = true
    }
  ])

  cpu = "256"
  memory = "512"
  execution_role_arn = aws_iam_role.ecs_task.arn
  task_role_arn = aws_iam_role.ecs_task.arn
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

resource "aws_iam_role_policy_attachment" "ecs_task_execution_role_policy" {
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
  role       = aws_iam_role.ecs_task.id
}

resource "aws_iam_policy" "cloudwatch_logs_policy" {
  name = "cloudwatch_logs_policy"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents",
          "logs:DescribeLogGroups",
          "logs:DescribeLogStreams",
          "logs:GetLogEvents"
        ]
        Resource = "*"
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "cloudwatch_logs_policy_attachment" {
  policy_arn = aws_iam_policy.cloudwatch_logs_policy.arn
  role       = aws_iam_role.ecs_task.id
}


resource "aws_cloudwatch_log_group" "app_log_group" {
  name = "/ecs/myapp"
  retention_in_days = 14
}

resource "aws_cloudwatch_log_group" "app_log_group2" {
  name = "my-log-group"
  retention_in_days = 14
}

output "ecs_service_url" {
  value = "${aws_lb_target_group.example.arn}"
}