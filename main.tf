terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 3.27"
    }
  }
  required_version = ">= 0.14.9"
}

provider "aws" {
  profile = "default"
  region  = "ap-southeast-1"
}
 
#1.Create VPC
resource "aws_vpc" "prod" {
  cidr_block = "10.0.0.0/16"
  tags = {
    Name = "production"
  }
}

#2.Create Internet gateway
resource "aws_internet_gateway" "prod_gateway" {
  vpc_id = aws_vpc.prod.id
  tags = {
    Name = "production gateway"
  }
}

#3.Route table
resource "aws_route_table" "prod_route_table" {
  vpc_id = aws_vpc.prod.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.prod_gateway.id
  }
  tags = {
    Name = "production route table"
  }
}

#4. Create Subnet
resource "aws_subnet" "prod_subnet_1" {
  vpc_id            = aws_vpc.prod.id
  cidr_block        = "10.0.1.0/24"
  availability_zone = "ap-southeast-1a"
  tags = {
    Name = "production subnet 1"
  }
}  

#5. Associate subnet with route table
resource "aws_route_table_association" "a" {
  subnet_id      = aws_subnet.prod_subnet_1.id
  route_table_id = aws_route_table.prod_route_table.id
}

#6. Create Security Group
resource "aws_security_group" "allow_web" {
  name        = "allow_web_traffic"
  description = "Allow Web inbound Traffic"
  vpc_id      = aws_vpc.prod.id

  ingress {
    description = "HTTPS"
    from_port   = 443
    to_port     = 447
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  ingress {
    description = "HTTP"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  ingress {
    description = "SSH"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "allow_web"
  }
}

#7 Create Network Interface
resource "aws_network_interface" "prod_network_interface" {
  subnet_id       = aws_subnet.prod_subnet_1.id
  private_ips     = ["10.0.1.50"]
  security_groups = [aws_security_group.allow_web.id]
}

#8 Create Elastic IP
resource "aws_eip" "one" {
  vpc                       = true
  network_interface         = aws_network_interface.prod_network_interface.id
  associate_with_private_ip = "10.0.1.50"
  depends_on                = [aws_internet_gateway.prod_gateway]
}

#9 Create Ubuntu Server
resource "aws_instance" "prod_ubuntu" {
  ami           = "ami-01811d4912b4ccb26"
  instance_type = "t2.micro"
  availability_zone = "ap-southeast-1a"
  key_name = "udemy-publice-key-pair"
  network_interface {
    network_interface_id = aws_network_interface.prod_network_interface.id
    device_index         = 0
  }
  user_data = <<-EOF
              #!/bin/bash
              sudo apt update
              sudo apt install apache2 -y
              sudo systemctl start apache2
              sudo bash -c 'echo "My first web server created by XXXXXXXXX" > /var/www/html/index.html'
              EOF
  tags = {
    Name = "production ubuntu"
  }
}

