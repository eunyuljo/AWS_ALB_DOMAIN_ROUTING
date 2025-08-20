# Target Groups for Different Domains

# Target Group 1: API 서비스 (api.example.com)
resource "aws_lb_target_group" "api_tg" {
  name     = "api-service-tg"
  port     = 8080
  protocol = "HTTP"
  vpc_id   = aws_vpc.main_vpc.id

  health_check {
    enabled             = true
    healthy_threshold   = 2
    interval            = 30
    matcher             = "200"
    path                = "/health"
    port                = "traffic-port"
    protocol            = "HTTP"
    timeout             = 5
    unhealthy_threshold = 2
  }

  tags = {
    Name    = "api-service-target-group"
    Domain  = "api.example.com"
    Service = "API"
  }
}

# Target Group 2: 웹 서비스 (www.example.com)
resource "aws_lb_target_group" "web_tg" {
  name     = "web-service-tg"
  port     = 80
  protocol = "HTTP"
  vpc_id   = aws_vpc.main_vpc.id

  health_check {
    enabled             = true
    healthy_threshold   = 2
    interval            = 30
    matcher             = "200"
    path                = "/"
    port                = "traffic-port"
    protocol            = "HTTP"
    timeout             = 5
    unhealthy_threshold = 2
  }

  tags = {
    Name    = "web-service-target-group"
    Domain  = "www.example.com"
    Service = "Web"
  }
}

# Target Group 3: 기본 서비스 (모든 미매치 도메인)
resource "aws_lb_target_group" "default_tg" {
  name     = "default-service-tg"
  port     = 80
  protocol = "HTTP"
  vpc_id   = aws_vpc.main_vpc.id

  health_check {
    enabled             = true
    healthy_threshold   = 2
    interval            = 30
    matcher             = "200,404"
    path                = "/"
    port                = "traffic-port"
    protocol            = "HTTP"
    timeout             = 5
    unhealthy_threshold = 2
  }

  tags = {
    Name    = "default-service-target-group"
    Domain  = "default"
    Service = "Default"
  }
}

# 타겟 그룹 연결 - ap-northeast-2a zone의 인스턴스만 등록
resource "aws_lb_target_group_attachment" "web_tg_attachment_2a" {
  target_group_arn = aws_lb_target_group.web_tg.arn
  target_id        = aws_instance.web_server_2a.id
  port             = 80
}

resource "aws_lb_target_group_attachment" "api_tg_attachment_2a" {
  target_group_arn = aws_lb_target_group.api_tg.arn
  target_id        = aws_instance.api_server_2a.id
  port             = 8080
}

resource "aws_lb_target_group_attachment" "default_tg_attachment_2a" {
  target_group_arn = aws_lb_target_group.default_tg.arn
  target_id        = aws_instance.web_server_2a.id
  port             = 80
}