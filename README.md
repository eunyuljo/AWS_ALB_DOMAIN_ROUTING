# AWS ALB Domain-based Routing with Single AZ Backend

This Terraform project demonstrates AWS Application Load Balancer (ALB) domain-based routing while deploying all backend targets in a single Availability Zone (ap-northeast-2a) for cost optimization.

## 🏗️ Architecture Overview

```
Internet
    │
    ▼
┌─────────────────────────────────────────────────────────────┐
│                    Internet Gateway                         │
└─────────────────────────────────────────────────────────────┘
    │
    ▼
┌─────────────────────────────────────────────────────────────┐
│                Application Load Balancer                   │
│              (deployed in 2a and 2c AZs)                  │
└─────────────────────────────────────────────────────────────┘
    │
    ▼ (Domain-based routing)
┌─────────────────────────────────────────────────────────────┐
│          ap-northeast-2a (Private Subnet)                  │
│                                                            │
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐        │
│  │ API Server  │  │ Web Server  │  │Default Sever│        │
│  │ (Node.js)   │  │  (Apache)   │  │  (Apache)   │        │
│  │   :8080     │  │    :80      │  │    :80      │        │
│  └─────────────┘  └─────────────┘  └─────────────┘        │
└─────────────────────────────────────────────────────────────┘
```

## 🌐 Domain Routing Configuration

| Domain | Target Service | Port | Health Check | Backend |
|--------|---------------|------|-------------|---------|
| `api.example.com` | API Server (Node.js) | 8080 | `/health` | i-xxx (2a) |
| `www.example.com` | Web Server (Apache) | 80 | `/` | i-yyy (2a) |
| `example.com` | Web Server (Apache) | 80 | `/` | i-yyy (2a) |
| `*` (all others) | Default Server (Apache) | 80 | `/` | i-yyy (2a) |

## 📋 Features

- ✅ **High Availability ALB**: Deployed across 2 AZs (2a, 2c)
- ✅ **Cost-Optimized Backend**: All servers in single AZ (2a)
- ✅ **Domain-based Routing**: Different domains → different services
- ✅ **Auto-scaling Ready**: Easy to extend to multi-AZ
- ✅ **SSM Access**: Built-in Session Manager support
- ✅ **Infrastructure as Code**: Fully automated deployment
- ✅ **Security Groups**: Proper network isolation

## 🚀 Quick Start

### Prerequisites

- Terraform >= 1.0
- AWS CLI configured with appropriate permissions
- Valid AWS key pair (optional, for SSH access)

### 1. Clone and Deploy

```bash
git clone <repository-url>
cd AWS_ALB_DOMAIN_ROUTING

# Initialize Terraform
terraform init

# Review the plan
terraform plan

# Deploy infrastructure
terraform apply
```

### 2. Test Domain Routing

After deployment, get the ALB DNS name:

```bash
terraform output alb_dns_name
```

Test different domain routing:

```bash
# Get ALB DNS name
ALB_DNS=$(terraform output -raw alb_dns_name)

# Test API endpoint
curl -H "Host: api.example.com" http://$ALB_DNS/health
curl -H "Host: api.example.com" http://$ALB_DNS/api/status

# Test web endpoints
curl -H "Host: www.example.com" http://$ALB_DNS/
curl -H "Host: example.com" http://$ALB_DNS/

# Test default routing
curl -H "Host: unknown.example.com" http://$ALB_DNS/
```

### 3. Access Servers via SSM

```bash
# Get instance IDs
terraform output ec2_instance_info

# Connect to API server
aws ssm start-session --target <api-server-instance-id>

# Connect to web server
aws ssm start-session --target <web-server-instance-id>
```

## 📁 Project Structure

```
AWS_ALB_DOMAIN_ROUTING/
├── main.tf              # Main infrastructure (VPC, EC2, ALB)
├── target_groups.tf     # ALB target groups and attachments
├── listeners.tf         # ALB listeners and routing rules
├── outputs.tf          # Output values and test commands
├── variables.tf        # Input variables
├── .gitignore          # Git ignore patterns
└── README.md           # This documentation
```

## 🔧 Configuration

### Variables

| Variable | Description | Default | Required |
|----------|-------------|---------|----------|
| `aws_region` | AWS region for deployment | `ap-northeast-2` | No |
| `instance_type` | EC2 instance type | `t3.micro` | No |
| `key_pair_name` | AWS key pair for SSH access | `eyjo-fnf-test-key` | No |

### Customization

Create a `terraform.tfvars` file for custom values:

```hcl
aws_region = "us-west-2"
instance_type = "t3.small"
key_pair_name = "my-key-pair"
```

## 🏛️ Infrastructure Components

### Network
- **VPC**: 10.0.0.0/16
- **Public Subnets**: 10.0.1.0/24 (2a), 10.0.2.0/24 (2c)
- **Private Subnets**: 10.0.3.0/24 (2a), 10.0.4.0/24 (2c)
- **NAT Gateway**: Single NAT in 2a for cost optimization

### Security
- **ALB Security Group**: 80, 443 from Internet
- **Web Security Group**: 80 from ALB, 22 from VPC
- **API Security Group**: 8080 from ALB, 22 from VPC
- **IAM Role**: SSM access for EC2 instances

### Services
- **API Server**: Node.js Express server on port 8080
- **Web Server**: Apache HTTP server on port 80
- **Health Checks**: Automated health monitoring

## 💰 Cost Considerations

### Current Architecture
- **Cross-AZ Traffic**: ALB (2c) → Backend (2a) incurs data transfer costs
- **NAT Gateway**: Single NAT reduces costs vs multi-AZ setup
- **Instance Hours**: Minimal with 2 t3.micro instances

### Cost Optimization Options

1. **Single AZ ALB** (reduces availability):
   ```hcl
   subnets = [aws_subnet.public_subnet_2a.id]
   ```

2. **Multi-AZ Backend** (increases availability):
   ```hcl
   # Add instances in 2c AZ
   resource "aws_instance" "api_server_2c" { ... }
   ```

## 🔄 Scaling and Extensions

### Add Auto Scaling

```hcl
resource "aws_autoscaling_group" "api_asg" {
  vpc_zone_identifier = [
    aws_subnet.private_subnet_2a.id,
    aws_subnet.private_subnet_2c.id  # Multi-AZ scaling
  ]
  target_group_arns = [aws_lb_target_group.api_tg.arn]
  # ... other configuration
}
```

### Add HTTPS Support

```hcl
resource "aws_lb_listener" "https" {
  load_balancer_arn = aws_lb.domain_routing_alb.arn
  port              = "443"
  protocol          = "HTTPS"
  ssl_policy        = "ELBSecurityPolicy-TLS-1-2-2017-01"
  certificate_arn   = var.certificate_arn
  # ... other configuration
}
```

## 🔍 Monitoring and Troubleshooting

### Check Service Status

```bash
# Via SSM
aws ssm send-command \
  --instance-ids <instance-id> \
  --document-name "AWS-RunShellScript" \
  --parameters 'commands=["systemctl status api-server"]'

# Via ALB Health Checks
aws elbv2 describe-target-health \
  --target-group-arn <target-group-arn>
```

### Common Issues

1. **503 Service Unavailable**: Check target group health
2. **Connection Timeout**: Verify security group rules
3. **Wrong Service Response**: Check ALB listener rules priority

## 🧹 Cleanup

To destroy all resources:

```bash
terraform destroy
```

**Note**: This will permanently delete all created resources.

## 🤝 Contributing

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Test thoroughly
5. Submit a pull request

## 📄 License

This project is for educational and demonstration purposes.

## 🆘 Support

For issues and questions:
- Check AWS CloudWatch logs
- Review Terraform state: `terraform show`
- Validate configuration: `terraform validate`

---

**Built with ❤️ using Terraform and AWS**