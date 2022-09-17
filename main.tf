provider "aws" {
  region = "us-east-1"
  profile = "default"
  }

# create VPC
resource "aws_vpc" "my_vpc" {
  cidr_block = "10.0.0.0/16"
  tags = {
    Name = "production"
  }
}

resource "aws_internet_gateway" "gw" {
  vpc_id = aws_vpc.my_vpc.id
}

resource "aws_route_table" "route_table" {
  vpc_id = aws_vpc.my_vpc.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.gw.id
  }
  route {
    ipv6_cidr_block = "::/0"
    gateway_id = aws_internet_gateway.gw.id
  }
  tags = {
    Name = "prod"
  }
}

resource "aws_subnet" "my_subnet" {
  vpc_id = aws_vpc.my_vpc.id
  cidr_block = "10.0.1.0/24"
  availability_zone = "us-east-1a"
  tags = {
    Name = "prod_subnet"
  }
}

resource "aws_route_table_association" "asso" {
  subnet_id = aws_subnet.my_subnet.id
  route_table_id = aws_route_table.route_table.id
}

resource "aws_security_group" "my_sec_group" {
  name = "allow_web_traffic"
  description = "allow web traffic"
  vpc_id = aws_vpc.my_vpc.id

  ingress {
    description = "HTTPS"
    from_port = 443
    to_port = 443
    protocol = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  ingress {
    description = "HTTP"
    from_port = 80
    to_port = 80
    protocol = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  ingress {
    description = "SSH"
    from_port = 2
    to_port = 2
    protocol = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port = 0
    to_port = 0
    protocol = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "allow_policies"
  }
}

resource "aws_network_interface" "web_server_nic" {
  subnet_id = aws_subnet.my_subnet.id
  private_ips = ["10.0.1.50"]
  security_groups = [aws_security_group.my_sec_group.id]
}

resource "aws_eip" "my_eip" {
  vpc = true
  network_interface = aws_network_interface.web_server_nic.id
  associate_with_private_ip = "10.0.1.50"
  depends_on = [aws_internet_gateway.gw]
}

resource "aws_instance" "web_server_instance" {
  ami = "ami-085925f297f89fce1"
  instance_type = "t2.micro"
  availability_zone = "us-east-1a"
  key_name = "di_keypair"
  network_interface {
    device_index         = 0
    network_interface_id = aws_network_interface.web_server_nic.id
  }
  user_data = <<-EOF
              #!/bin/bash
              sudo apt update -y
              sudo apt install apache2 -y
              sudo systemctl start apache2
              sudo bash -c 'echo your very first web server > /var/www/html/index.html'
              EOF
  tags = {
    Name = "web-server"
  }
}
