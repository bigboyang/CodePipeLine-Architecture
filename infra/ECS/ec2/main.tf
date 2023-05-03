
# VPC
resource "aws_vpc" "example" {
  cidr_block = "10.0.0.0/16"
  tags = {
    Name = "temp-vpc"
  }
}

resource "aws_security_group" "example" {
  name_prefix = "temp-sg-"

  ingress {
    description = "Allow HTTP"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "Allow HTTP"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "Allow HTTP"
    from_port   = 9000
    to_port     = 9000
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

  ingress {
    description = "Allow application traffic"
    from_port   = 8088
    to_port     = 8088
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

# Private subnet
resource "aws_subnet" "private2" {
  vpc_id            = aws_vpc.example.id
  cidr_block        = "10.0.8.0/24"
  availability_zone = "ap-northeast-2b"

  tags = {
    Name = "private2"
  }
}


# Internet Gateway
resource "aws_internet_gateway" "example" {
  vpc_id = aws_vpc.example.id

  tags = {
    Name = "temp-igw"
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
    Name = "temp-nat-gateway"
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

# Associate private subnet with private route table
resource "aws_route_table_association" "private2" {
  subnet_id      = aws_subnet.private2.id
  route_table_id = aws_route_table.private.id
}

# data "template_file" "userdata" {
#   template = file("templates/userdata.sh")
# }

data "aws_ami" "this" {
  most_recent = true
  owners      = ["amazon"]

  dynamic "filter" {
    for_each = [
        {
          name   = "name"
          values = ["amzn2-ami-hvm-*-x86_64-gp2"]
        }
    ]
    content {
      name = lookup(filter.value, "name")
      values = lookup(filter.value, "values")
    }
  }
}

# EC2 instance
module "ec2" {
  source = "terraform-aws-modules/ec2-instance/aws"

  name = "temp-temp-server"

  ami                         = data.aws_ami.this.id
  key_name                    = "dev"
  instance_type               = "t2.micro"
  availability_zone           = "ap-northeast-2a"
  subnet_id                   = aws_subnet.public.id
  vpc_security_group_ids      = [aws_security_group.example.id]
  # user_data                   = data.template_file.userdata.rendered

  user_data = <<-EOF
              #!/bin/bash
              echo ECS_CLUSTER=${aws_ecs_cluster.ec2_cluster.arn} >> /etc/ecs/ecs.config
              EOF

  tags = {
    Name = "temp-server"
  }
}


# bastian host
module "ec2-bastian" {
  source = "terraform-aws-modules/ec2-instance/aws"

  name = "bastian-host"

  ami                         = data.aws_ami.this.id
  key_name                    = "dev"
  instance_type               = "t2.micro"
  availability_zone           = "ap-northeast-2a"
  subnet_id                   = aws_subnet.public.id
  vpc_security_group_ids      = [aws_security_group.example.id]
  associate_public_ip_address = true

  tags = {
    Name = "bastian-host"
  }
}


# ALB
resource "aws_lb" "alb" {
  name            = "temp-my-alb"
  internal        = false
  load_balancer_type = "application"
  security_groups = [aws_security_group.example.id]
  subnets         = [aws_subnet.public.id, aws_subnet.public2.id]

  tags = {
    Name = "my-alb"
  }
}

# Target Group for ECS Service
resource "aws_lb_target_group" "ecs_target_group" {
  name_prefix = "temptg"
  port        = 8088
  protocol    = "HTTP"
  vpc_id      = aws_vpc.example.id

  tags = {
    Name = "temp-ecs-tg"
  }
}

# ECS Cluster
resource "aws_ecs_cluster" "ec2_cluster" {
  name = "temp-ec2-cluster"
}

# Auto Scaling Group Launch Configuration
resource "aws_launch_configuration" "ec2_cluster_lc" {
  name_prefix   = "temp-ec2-cluster-lc-"
  image_id      = data.aws_ami.this.id
  instance_type = "t3.micro"
  key_name      = "dev" # 키페어 이름 지정
  security_groups = [
    aws_security_group.example.id,
  ]
  user_data = <<-EOF
              #!/bin/bash
              echo ECS_CLUSTER=${aws_ecs_cluster.ec2_cluster.arn} >> /etc/ecs/ecs.config
              EOF
}

# Auto Scaling Group
resource "aws_autoscaling_group" "ec2_cluster_asg" {
  name = "ec2-cluster-asg"

  vpc_zone_identifier = [aws_subnet.public.id,aws_subnet.public2.id]
  launch_configuration = aws_launch_configuration.ec2_cluster_lc.name
  # availability_zones        = ["ap-northeast-2a", "ap-northeast-2c"]

  min_size             = 1
  max_size             = 2
  desired_capacity     = 2
  

  target_group_arns = [
    aws_lb_target_group.ecs_target_group.arn
  ]

   tags = [
    {
      key                 = "Name"
      value               = "ec2-cluster-asg"
      propagate_at_launch = true
    },
  ]
}

resource "aws_ecs_capacity_provider" "my_cluster_cp" {
  name           = "my-cluster-cp"
  auto_scaling_group_provider {
    auto_scaling_group_arn = aws_autoscaling_group.ec2_cluster_asg.arn
    managed_scaling {
      maximum_scaling_step_size = 2
      minimum_scaling_step_size = 1
      status                    = "ENABLED"
      target_capacity           = 50
    }
  }
  tags = {
    Name = "My Cluster Capacity Provider"
  }
}








# # 오로라 서브넷 그룹
# resource "aws_db_subnet_group" "aurora_subnet_group" {
#   name       = "temp-aurora-subnet-group"
#   subnet_ids = [aws_subnet.private.id, aws_subnet.private2.id]

#   tags = {
#     Name = "temp-aurora-subnet-group"
#   }
# }


# resource "aws_rds_cluster" "aurora_cluster" {
#   cluster_identifier         = "aurora-cluster"
#   engine                     = "aurora"
#   engine_mode                = "serverless"
#   engine_version             = "5.6.10a"
#   database_name              = "mydb"
#   master_username            = "admin"
#   master_password            = "mypassword"
#   skip_final_snapshot        = true
#   backup_retention_period    = 7
#   preferred_backup_window    = "07:00-09:00"
#   preferred_maintenance_window = "mon:05:00-mon:06:00"

#   scaling_configuration {
#     auto_pause = true
#     max_capacity = 2
#     min_capacity = 1
#     seconds_until_auto_pause = 300
#   }

#   tags = {
#     Name = "aurora-serverless-cluster"
#   }
# }

# resource "aws_security_group" "aurora_cluster_sg" {
#   name_prefix = "temp-aurora-cluster-sg"
#   vpc_id = aws_vpc.example.id

#   ingress {
#     from_port   = 3306
#     to_port     = 3306
#     protocol    = "tcp"
#     cidr_blocks = [aws_vpc.example.cidr_block]
#   }

#   tags = {
#     Name = "temp-aurora-cluster-sg"
#   }
# }