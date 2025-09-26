# ALB Domain-based Routing Example
terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = var.aws_region
}

# VPC 생성
resource "aws_vpc" "main_vpc" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = {
    Name = "main-vpc"
  }
}

# Internet Gateway
resource "aws_internet_gateway" "main_igw" {
  vpc_id = aws_vpc.main_vpc.id

  tags = {
    Name = "main-igw"
  }
}

# ap-northeast-2a 퍼블릭 서브넷
resource "aws_subnet" "public_subnet_2a" {
  vpc_id                  = aws_vpc.main_vpc.id
  cidr_block              = "10.0.1.0/24"
  availability_zone       = "ap-northeast-2a"
  map_public_ip_on_launch = true

  tags = {
    Name = "public-subnet-2a"
  }
}

# ap-northeast-2c 퍼블릭 서브넷
resource "aws_subnet" "public_subnet_2c" {
  vpc_id                  = aws_vpc.main_vpc.id
  cidr_block              = "10.0.2.0/24"
  availability_zone       = "ap-northeast-2c"
  map_public_ip_on_launch = true

  tags = {
    Name = "public-subnet-2c"
  }
}

# ap-northeast-2a 프라이빗 서브넷
resource "aws_subnet" "private_subnet_2a" {
  vpc_id            = aws_vpc.main_vpc.id
  cidr_block        = "10.0.3.0/24"
  availability_zone = "ap-northeast-2a"

  tags = {
    Name = "private-subnet-2a"
  }
}

# ap-northeast-2c 프라이빗 서브넷
resource "aws_subnet" "private_subnet_2c" {
  vpc_id            = aws_vpc.main_vpc.id
  cidr_block        = "10.0.4.0/24"
  availability_zone = "ap-northeast-2c"

  tags = {
    Name = "private-subnet-2c"
  }
}

# 퍼블릭 라우팅 테이블
resource "aws_route_table" "public_rt" {
  vpc_id = aws_vpc.main_vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.main_igw.id
  }

  tags = {
    Name = "public-rt"
  }
}

# 퍼블릭 라우팅 테이블 연결
resource "aws_route_table_association" "public_rta_2a" {
  subnet_id      = aws_subnet.public_subnet_2a.id
  route_table_id = aws_route_table.public_rt.id
}

resource "aws_route_table_association" "public_rta_2c" {
  subnet_id      = aws_subnet.public_subnet_2c.id
  route_table_id = aws_route_table.public_rt.id
}

# Security Group for ALB
resource "aws_security_group" "alb_sg" {
  name        = "alb-domain-routing-sg"
  description = "Security group for ALB with domain routing"
  vpc_id      = aws_vpc.main_vpc.id

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

  tags = {
    Name = "alb-domain-routing-sg"
  }
}

# Application Load Balancer
resource "aws_lb" "domain_routing_alb" {
  name               = "domain-routing-alb-demo"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.alb_sg.id]
  subnets = [
    aws_subnet.public_subnet_2a.id,
    aws_subnet.public_subnet_2c.id
  ]

  enable_deletion_protection = false

  tags = {
    Environment = "demo"
    Purpose     = "domain-routing-example"
  }
}

# IAM 역할 - EC2 SSM 접근용
resource "aws_iam_role" "ec2_ssm_role" {
  name = "EC2-SSM-Role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
      }
    ]
  })

  tags = {
    Name = "EC2-SSM-Role"
  }
}

# IAM 정책 연결 - SSM 기본 권한
resource "aws_iam_role_policy_attachment" "ssm_managed_instance_core" {
  role       = aws_iam_role.ec2_ssm_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

# CloudWatch 에이전트용 정책 (선택적)
resource "aws_iam_role_policy_attachment" "cloudwatch_agent_server_policy" {
  role       = aws_iam_role.ec2_ssm_role.name
  policy_arn = "arn:aws:iam::aws:policy/CloudWatchAgentServerPolicy"
}

# 인스턴스 프로파일 생성
resource "aws_iam_instance_profile" "ec2_ssm_profile" {
  name = "EC2-SSM-Profile"
  role = aws_iam_role.ec2_ssm_role.name

  tags = {
    Name = "EC2-SSM-Profile"
  }
}

# 웹 서버 보안 그룹 (ap-northeast-2a zone만 대상)
resource "aws_security_group" "web_sg" {
  name        = "web-sg"
  description = "Security group for web servers"
  vpc_id      = aws_vpc.main_vpc.id

  ingress {
    from_port       = 80
    to_port         = 80
    protocol        = "tcp"
    security_groups = [aws_security_group.alb_sg.id]
  }

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["10.0.0.0/16"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "web-sg"
  }
}

# ap-northeast-2a zone에만 배치될 EC2 인스턴스 (웹 서버)
resource "aws_instance" "web_server_2a" {
  ami                    = "ami-0c2acfcb2ac4d02a0"
  instance_type          = "t3.micro"
  subnet_id              = aws_subnet.private_subnet_2a.id
  vpc_security_group_ids = [aws_security_group.web_sg.id]
  iam_instance_profile   = aws_iam_instance_profile.ec2_ssm_profile.name

  user_data = <<-EOF
              #!/bin/bash
              yum update -y
              yum install -y httpd
              systemctl start httpd
              systemctl enable httpd
              echo "<h1>Web Server in ap-northeast-2a</h1>" > /var/www/html/index.html
              echo "<p>This server is only in ap-northeast-2a availability zone</p>" >> /var/www/html/index.html
              EOF

  tags = {
    Name = "web-server-2a"
  }
}

# API 서버용 보안 그룹
resource "aws_security_group" "api_sg" {
  name        = "api-sg"
  description = "Security group for API servers"
  vpc_id      = aws_vpc.main_vpc.id

  ingress {
    from_port       = 8080
    to_port         = 8080
    protocol        = "tcp"
    security_groups = [aws_security_group.alb_sg.id]
  }

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["10.0.0.0/16"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "api-sg"
  }
}

# ap-northeast-2a zone에만 배치될 EC2 인스턴스 (API 서버)
resource "aws_instance" "api_server_2a" {
  ami                    = "ami-0c2acfcb2ac4d02a0"
  instance_type          = "t3.micro"
  subnet_id              = aws_subnet.private_subnet_2a.id
  vpc_security_group_ids = [aws_security_group.api_sg.id]
  iam_instance_profile   = aws_iam_instance_profile.ec2_ssm_profile.name

  user_data = <<-EOF
#!/bin/bash
yum update -y
yum install -y nodejs npm

# API 서버 디렉토리 생성
mkdir -p /opt/api-server
cd /opt/api-server

# package.json 생성
cat > package.json << 'PACKAGE_EOF'
{
  "name": "api-server",
  "version": "1.0.0",
  "description": "Simple API Server for ALB Demo",
  "main": "server.js",
  "scripts": {
    "start": "node server.js"
  },
  "dependencies": {
    "express": "^4.18.0"
  }
}
PACKAGE_EOF

# Express 설치
npm install

# API 서버 코드 생성
cat > server.js << 'SERVER_EOF'
const express = require('express');
const app = express();
const port = 8080;

app.get('/health', (req, res) => {
  res.status(200).json({
    status: 'healthy',
    message: 'API Server in ap-northeast-2a',
    timestamp: new Date().toISOString(),
    zone: 'ap-northeast-2a'
  });
});

app.get('/', (req, res) => {
  res.json({
    service: 'API Server',
    zone: 'ap-northeast-2a',
    message: 'This is the API service endpoint',
    endpoints: ['/health', '/api/status']
  });
});

app.get('/api/status', (req, res) => {
  res.json({
    status: 'running',
    uptime: process.uptime(),
    zone: 'ap-northeast-2a',
    server: 'api-server-2a'
  });
});

app.listen(port, '0.0.0.0', () => {
  console.log('API Server running on port ' + port + ' in ap-northeast-2a');
});
SERVER_EOF

# systemd 서비스 생성
cat > /etc/systemd/system/api-server.service << 'SERVICE_EOF'
[Unit]
Description=API Server
After=network.target

[Service]
Type=simple
User=ec2-user
WorkingDirectory=/opt/api-server
ExecStart=/usr/bin/node server.js
Restart=always
RestartSec=10

[Install]
WantedBy=multi-user.target
SERVICE_EOF

# 서비스 시작 및 활성화
systemctl daemon-reload
systemctl enable api-server
systemctl start api-server

# 소유권 변경
chown -R ec2-user:ec2-user /opt/api-server
EOF

  tags = {
    Name = "api-server-2a"
  }
}

# NAT Gateway용 Elastic IP (프라이빗 서브넷의 인터넷 접근용)
resource "aws_eip" "nat_eip" {
  domain = "vpc"

  tags = {
    Name = "nat-eip"
  }
}

# NAT Gateway (ap-northeast-2a에만 생성)
resource "aws_nat_gateway" "main_nat" {
  allocation_id = aws_eip.nat_eip.id
  subnet_id     = aws_subnet.public_subnet_2a.id

  tags = {
    Name = "main-nat-gw"
  }

  depends_on = [aws_internet_gateway.main_igw]
}

# 프라이빗 라우팅 테이블
resource "aws_route_table" "private_rt" {
  vpc_id = aws_vpc.main_vpc.id

  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.main_nat.id
  }

  tags = {
    Name = "private-rt"
  }
}

# 프라이빗 라우팅 테이블 연결
resource "aws_route_table_association" "private_rta_2a" {
  subnet_id      = aws_subnet.private_subnet_2a.id
  route_table_id = aws_route_table.private_rt.id
}

resource "aws_route_table_association" "private_rta_2c" {
  subnet_id      = aws_subnet.private_subnet_2c.id
  route_table_id = aws_route_table.private_rt.id
}

# ap-northeast-2a zone에 배치될 EC2 인스턴스 (테스트 서버)
resource "aws_instance" "test_server_2a" {
  ami                    = "ami-0c2acfcb2ac4d02a0"
  instance_type          = "t3.micro"
  subnet_id              = aws_subnet.private_subnet_2a.id
  vpc_security_group_ids = [aws_security_group.web_sg.id]
  iam_instance_profile   = aws_iam_instance_profile.ec2_ssm_profile.name

  user_data = <<-EOF
              #!/bin/bash
              yum update -y
              yum install -y httpd
              systemctl start httpd
              systemctl enable httpd
              echo "<h1>Test Server in ap-northeast-2a</h1>" > /var/www/html/index.html
              echo "<p>This server is for test.com domain routing</p>" >> /var/www/html/index.html
              echo "<p>Running in ap-northeast-2a availability zone</p>" >> /var/www/html/index.html
              echo "<p>Server ID: test-server-2a</p>" >> /var/www/html/index.html
              EOF

  tags = {
    Name = "test-server-2a"
  }
}

# ap-northeast-2c zone에 배치될 EC2 인스턴스 (테스트 서버)
resource "aws_instance" "test_server_2c" {
  ami                    = "ami-0c2acfcb2ac4d02a0"
  instance_type          = "t3.micro"
  subnet_id              = aws_subnet.private_subnet_2c.id
  vpc_security_group_ids = [aws_security_group.web_sg.id]
  iam_instance_profile   = aws_iam_instance_profile.ec2_ssm_profile.name

  user_data = <<-EOF
              #!/bin/bash
              yum update -y
              yum install -y httpd
              systemctl start httpd
              systemctl enable httpd
              echo "<h1>Test Server in ap-northeast-2c</h1>" > /var/www/html/index.html
              echo "<p>This server is for test.com domain routing</p>" >> /var/www/html/index.html
              echo "<p>Running in ap-northeast-2c availability zone</p>" >> /var/www/html/index.html
              echo "<p>Server ID: test-server-2c</p>" >> /var/www/html/index.html
              EOF

  tags = {
    Name = "test-server-2c"
  }
}