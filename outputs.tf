# Output values for ALB Domain Routing

output "alb_dns_name" {
  description = "DNS name of the Application Load Balancer"
  value       = aws_lb.domain_routing_alb.dns_name
}

output "alb_zone_id" {
  description = "Zone ID of the Application Load Balancer"
  value       = aws_lb.domain_routing_alb.zone_id
}

output "target_group_arns" {
  description = "ARNs of all target groups"
  value = {
    api     = aws_lb_target_group.api_tg.arn
    web     = aws_lb_target_group.web_tg.arn
    default = aws_lb_target_group.default_tg.arn
  }
}

output "vpc_info" {
  description = "VPC and subnet information"
  value = {
    vpc_id               = aws_vpc.main_vpc.id
    public_subnet_2a_id  = aws_subnet.public_subnet_2a.id
    public_subnet_2c_id  = aws_subnet.public_subnet_2c.id
    private_subnet_2a_id = aws_subnet.private_subnet_2a.id
    private_subnet_2c_id = aws_subnet.private_subnet_2c.id
  }
}

output "ec2_instance_info" {
  description = "EC2 instance information in ap-northeast-2a"
  value = {
    web_server = {
      instance_id       = aws_instance.web_server_2a.id
      private_ip        = aws_instance.web_server_2a.private_ip
      availability_zone = aws_instance.web_server_2a.availability_zone
    }
    api_server = {
      instance_id       = aws_instance.api_server_2a.id
      private_ip        = aws_instance.api_server_2a.private_ip
      availability_zone = aws_instance.api_server_2a.availability_zone
    }
  }
}

output "routing_test_commands" {
  description = "Commands to test domain routing (targets only in ap-northeast-2a)"
  value = <<-EOT
    # Test API domain routing → API Server (8080 port)
    curl -H "Host: api.example.com" http://${aws_lb.domain_routing_alb.dns_name}/health
    curl -H "Host: api.example.com" http://${aws_lb.domain_routing_alb.dns_name}/api/status
    
    # Test Web domain routing → Web Server (80 port)
    curl -H "Host: www.example.com" http://${aws_lb.domain_routing_alb.dns_name}/
    curl -H "Host: example.com" http://${aws_lb.domain_routing_alb.dns_name}/
    
    # Test default routing → Web Server (80 port)
    curl -H "Host: unknown.example.com" http://${aws_lb.domain_routing_alb.dns_name}/
    
    # ALB는 2a, 2c 모든 AZ에 배치, API/Web 서버는 각각 전용 EC2로 분리됨
  EOT
}

output "ssm_connect_commands" {
  description = "SSM Session Manager connection commands"
  value = <<-EOT
    # Connect to API Server
    aws ssm start-session --target ${aws_instance.api_server_2a.id}
    
    # Connect to Web Server  
    aws ssm start-session --target ${aws_instance.web_server_2a.id}
    
    # Send commands via SSM
    aws ssm send-command --instance-ids ${aws_instance.api_server_2a.id} --document-name "AWS-RunShellScript" --parameters 'commands=["systemctl status api-server"]'
  EOT
}