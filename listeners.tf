# ALB Listeners and Rules for Domain-based Routing

# HTTP Listener (Port 80)
resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.domain_routing_alb.arn
  port              = "80"
  protocol          = "HTTP"

  # 기본 액션: 매치되지 않는 모든 요청은 기본 타겟 그룹으로
  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.default_tg.arn
  }

  tags = {
    Name = "http-listener"
  }
}

# 도메인별 라우팅 규칙들
# 규칙 1: api.example.com → API 서비스
resource "aws_lb_listener_rule" "api_domain" {
  listener_arn = aws_lb_listener.http.arn
  priority     = 100

  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.api_tg.arn
  }

  condition {
    host_header {
      values = ["api.example.com"]
    }
  }

  tags = {
    Name   = "api-domain-rule"
    Domain = "api.example.com"
  }
}

# 규칙 2: www.example.com → 웹 서비스
resource "aws_lb_listener_rule" "web_domain" {
  listener_arn = aws_lb_listener.http.arn
  priority     = 200

  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.web_tg.arn
  }

  condition {
    host_header {
      values = ["www.example.com", "example.com"]
    }
  }

  tags = {
    Name   = "web-domain-rule"
    Domain = "www.example.com"
  }
}