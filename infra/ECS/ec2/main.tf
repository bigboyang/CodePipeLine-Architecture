
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

data "template_file" "userdata" {
  template = file("templates/userdata.sh")
}

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
  user_data                   = data.template_file.userdata.rendered

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

