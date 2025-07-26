provider "aws" {
  region = "us-east-1"
}

resource "aws_vpc" "sonar_vpc" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = {
    Name = "sonar-vpc"
  }
}

resource "aws_internet_gateway" "sonar_igw" {
  vpc_id = aws_vpc.sonar_vpc.id

  tags = {
    Name = "sonar-igw"
  }
}

resource "aws_subnet" "sonar_subnet" {
  vpc_id                  = aws_vpc.sonar_vpc.id
  cidr_block              = "10.0.1.0/24"
  map_public_ip_on_launch = true

  tags = {
    Name = "sonar-subnet"
  }
}

resource "aws_route_table" "sonar_rt" {
  vpc_id = aws_vpc.sonar_vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.sonar_igw.id
  }

  tags = {
    Name = "sonar-rt"
  }
}

resource "aws_route_table_association" "sonar_rta" {
  subnet_id      = aws_subnet.sonar_subnet.id
  route_table_id = aws_route_table.sonar_rt.id
}


resource "aws_security_group" "sonar_sg" {
  name        = "sonar-sg"
  description = "Allow SSH and SonarQube access"
  vpc_id      = aws_vpc.sonar_vpc.id

  ingress {
    description = "SSH"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "SonarQube Web UI"
    from_port   = 9000
    to_port     = 9000
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
    Name = "sonar-sg"
  }
}


resource "aws_instance" "sonar_server" {
  ami           = "ami-0c2b8ca1dad447f8a"  # Amazon Linux 2 or replace with Ubuntu
  instance_type = "t3.medium"  # Minimum for SonarQube
  key_name      = "sonar-key"
  subnet_id     = aws_subnet.sonar_subnet.id
  vpc_security_group_ids = [aws_security_group.sonar_sg.id]
  associate_public_ip_address = true

  user_data = <<-EOF
              #!/bin/bash
              yum update -y
              amazon-linux-extras install java-openjdk17 -y
              yum install wget unzip -y

              # Download SonarQube
              wget https://binaries.sonarsource.com/Distribution/sonarqube/sonarqube-25.7.0.110598.zip
              unzip sonarqube-25.7.0.110598.zip -d /opt/
              mv /opt/sonarqube-25.7.0.110598 /opt/sonarqube

              # Create sonar user
              useradd sonar
              chown -R sonar:sonar /opt/sonarqube

              # Start SonarQube
              su - sonar -c "/opt/sonarqube/bin/linux-x86-64/sonar.sh start"
              EOF

  tags = {
    Name = "SonarQube-Server"
  }
}

output "sonarqube_public_ip" {
  description = "Public IP address of the SonarQube EC2 instance"
  value       = aws_instance.sonar_server.public_ip
}

output "sonarqube_url" {
  description = "URL to access SonarQube Web UI"
  value       = "http://${aws_instance.sonar_server.public_ip}:9000"
}

