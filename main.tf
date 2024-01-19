terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  access_key = var.aws_access_key
  secret_key = var.aws_secret_key
  region     = var.region
}

resource "aws_key_pair" "mykey" {
  key_name   = "mykey"
  public_key = file("~/.ssh/mykey.pub")
}

resource "aws_vpc" "segun" {
  cidr_block = "10.0.0.0/16"
  enable_dns_support = true
  enable_dns_hostnames = true
  tags = {
    Name = "segun-vpc"
  }
}

resource "aws_internet_gateway" "example" {
  vpc_id = aws_vpc.segun.id
}

resource "aws_route" "example" {
  route_table_id         = aws_vpc.segun.main_route_table_id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.example.id
}

resource "aws_route_table" "example" {
  vpc_id = aws_vpc.segun.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.example.id
  }
}

resource "aws_subnet" "public_subnet" {
  depends_on = [aws_vpc.segun]
  vpc_id                  = aws_vpc.segun.id
  cidr_block              = "10.0.0.0/24"
  availability_zone       = "us-east-1a"
  map_public_ip_on_launch = true
    tags = {
    Name = "public-subnet"
  }
}

resource "aws_subnet" "private_subnet" {
  depends_on = [aws_vpc.segun]
  vpc_id                  = aws_vpc.segun.id
  cidr_block              = "10.0.1.0/24"
  availability_zone       = "us-east-1b"
  map_public_ip_on_launch = false
  tags = {
    Name = "private-subnet"
  }
}

resource "aws_route_table_association" "public_subnet_association" {
  subnet_id      = aws_subnet.public_subnet.id
  route_table_id = aws_vpc.segun.main_route_table_id
}

resource "aws_route_table_association" "private_subnet_association" {
  subnet_id      = aws_subnet.private_subnet.id
  route_table_id = aws_vpc.segun.main_route_table_id
}


resource "aws_security_group" "segun" {
  depends_on = [aws_vpc.segun]
  vpc_id = aws_vpc.segun.id
  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"] 
  }

  egress {
  from_port   = 0
  to_port     = 0
  protocol    = "-1"
  cidr_blocks = ["0.0.0.0/0"]
}
}

resource "aws_instance" "segun_instances" {
  depends_on = [aws_subnet.public_subnet, aws_security_group.segun]
  count         = var.instance_count
  ami           = "ami-0005e0cfe09cc9050"
  instance_type = var.instance_type
  key_name      = aws_key_pair.mykey.key_name
  subnet_id     = aws_subnet.public_subnet.id
  vpc_security_group_ids = [aws_security_group.segun.id]
  tags = {
    Name = "segun-web-instance-${count.index + 1}"
  }
}


resource "aws_elb" "load_balancer" {
  depends_on = [aws_subnet.public_subnet, aws_security_group.segun, aws_instance.segun_instances]
  name               = "terraform-elb"
  internal           = false
  security_groups    = [aws_security_group.segun.id]
  instances          = aws_instance.segun_instances[*].id
  cross_zone_load_balancing = true
  
  listener {
    instance_port     = 80
    instance_protocol = "HTTP"
    lb_port           = 80
    lb_protocol       = "HTTP"
  }

  health_check {
    target              = "HTTP:80/"
    interval            = 30
    timeout             = 3
    healthy_threshold   = 2
    unhealthy_threshold = 2
  }
  subnets = [aws_subnet.public_subnet.id, aws_subnet.private_subnet.id]
}


resource "aws_route53_zone" "main" {
  name = var.domain_name
}

resource "aws_route53_record" "subdomain" {
  zone_id = aws_route53_zone.main.zone_id
  name    = "terraform-test"
  type    = "CNAME"
  ttl     = "60"
  records = [aws_elb.load_balancer.dns_name]
}

data "aws_subnet" "public_subnets" {
    vpc_id = aws_vpc.segun.id
  cidr_block = "10.0.0.0/24"
}

data "aws_subnet" "private_subnets" {
    vpc_id = aws_vpc.segun.id
  cidr_block = "10.0.1.0/24"
}

output "public_subnet" {
  value = aws_subnet.public_subnet.id
}

output "private_subnet" {
  value = aws_subnet.private_subnet.id
}


output "host_inventory" {
  value = aws_instance.segun_instances[*].public_ip
}