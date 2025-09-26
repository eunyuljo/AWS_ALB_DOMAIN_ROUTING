# AWS ALB 도메인 기반 라우팅 with 멀티 AZ 아키텍처

이 Terraform 프로젝트는 AWS Application Load Balancer(ALB)를 사용한 도메인 기반 라우팅을 구현합니다. 서로 다른 도메인 요청을 각각 다른 백엔드 서비스로 라우팅하며, 멀티 AZ 배포를 통한 고가용성을 제공합니다.

## 🏗️ 아키텍처 개요

```
인터넷
    │
    ▼
┌─────────────────────────────────────────────────────────────┐
│                  인터넷 게이트웨이                           │
└─────────────────────────────────────────────────────────────┘
    │
    ▼
┌─────────────────────────────────────────────────────────────┐
│              애플리케이션 로드 밸런서                         │
│              (2a 및 2c AZ에 배포)                            │
└─────────────────────────────────────────────────────────────┘
    │
    ▼ (도메인 기반 라우팅)
┌──────────────────────────────────┬──────────────────────────────────┐
│     ap-northeast-2a (프라이빗)    │     ap-northeast-2c (프라이빗)    │
│                                  │                                  │
│  ┌─────────────┐                 │                                  │
│  │ API 서버    │                  │                                 │
│  │ (Node.js)   │                 │                                  │
│  │   :8080     │                 │                                  │
│  └─────────────┘                 │                                  │
│                                  │                                  │
│  ┌─────────────┐                 │                                  │
│  │ 웹 서버      │                 │                                  │
│  │  (Apache)   │                 │                                  │
│  │    :80      │                 │                                  │
│  └─────────────┘                 │                                  │
│                                  │                                  │
│  ┌─────────────┐                 │  ┌─────────────┐                 │
│  │ 테스트 서버  │                 │  │ 테스트 서버  │                 │
│  │  (Apache)   │                 │  │  (Apache)   │                 │
│  │    :80      │                 │  │    :80      │                 │
│  └─────────────┘                 │  └─────────────┘                 │
└──────────────────────────────────┴──────────────────────────────────┘
```

## 🌐 도메인 라우팅 설정

| 도메인 | 대상 서비스 | 포트 | 헬스 체크 | 백엔드 |
|--------|-------------|------|-----------|---------|
| `api.example.com` | API 서버 (Node.js) | 8080 | `/health` | api-server-2a (2a 전용) |
| `www.example.com` | 웹 서버 (Apache) | 80 | `/` | web-server-2a (2a 전용) |
| `example.com` | 웹 서버 (Apache) | 80 | `/` | web-server-2a (2a 전용) |
| `test.com` | 테스트 서버 (Apache) | 80 | `/` | test-server-2a (2a) + test-server-2c (2c) |
| `*` (기타 모든 도메인) | 기본 서버 (Apache) | 80 | `/` | web-server-2a (2a) |

## 📋 주요 기능

- ✅ **고가용성 ALB**: 2개 AZ(2a, 2c)에 배포
- ✅ **도메인 기반 라우팅**: 서로 다른 도메인을 각각 다른 서비스로 라우팅
- ✅ **멀티 서비스 지원**: API 서버, 웹 서버, 테스트 서버 분리 운영
- ✅ **멀티 AZ 테스트**: test.com 도메인은 2a와 2c 양쪽 AZ에 배포
- ✅ **SSM 접근**: 세션 매니저를 통한 보안 서버 접근
- ✅ **코드형 인프라**: Terraform을 통한 완전 자동화 배포
- ✅ **보안 그룹**: 서비스별 적절한 네트워크 격리
- ✅ **헬스 체크**: 각 서비스별 맞춤형 헬스 체크 구성

## 🚀 빠른 시작

### 사전 요구사항

- Terraform >= 1.0
- 적절한 권한으로 구성된 AWS CLI
- 유효한 AWS 키 페어 (선택사항, SSH 접근용)

### 1. 클론 및 배포

```bash
git clone <repository-url>
cd AWS_ALB_DOMAIN_ROUTING

# Terraform 초기화
terraform init

# 계획 검토
terraform plan

# 인프라 배포
terraform apply
```

### 2. 도메인 라우팅 테스트

배포 후 ALB DNS 이름 확인:

```bash
terraform output alb_dns_name
```

다양한 도메인 라우팅 테스트:

```bash
# ALB DNS 이름 가져오기
ALB_DNS=$(terraform output -raw alb_dns_name)

# API 엔드포인트 테스트
curl -H "Host: api.example.com" http://$ALB_DNS/health
curl -H "Host: api.example.com" http://$ALB_DNS/api/status

# 웹 엔드포인트 테스트
curl -H "Host: www.example.com" http://$ALB_DNS/
curl -H "Host: example.com" http://$ALB_DNS/

# 테스트 서버 테스트 (멀티 AZ)
curl -H "Host: test.com" http://$ALB_DNS/

# 기본 라우팅 테스트
curl -H "Host: unknown.example.com" http://$ALB_DNS/
```

### 3. SSM을 통한 서버 접근

```bash
# 인스턴스 ID 및 연결 명령어 확인
terraform output ec2_instance_info
terraform output ssm_connect_commands

# 서버 연결
aws ssm start-session --target <api-server-instance-id>    # API 서버 (2a)
aws ssm start-session --target <web-server-instance-id>    # 웹 서버 (2a)
aws ssm start-session --target <test-server-2a-instance-id> # 테스트 서버 (2a)
aws ssm start-session --target <test-server-2c-instance-id> # 테스트 서버 (2c)
```

### 4. 멀티 AZ 테스트

```bash
# 테스트 서버의 멀티 AZ 동작 확인 (test.com 도메인)
# 여러 번 요청하여 로드 밸런싱 확인
for i in {1..10}; do
  curl -H "Host: test.com" http://$ALB_DNS/
  echo ""
done

# 각 서버에 직접 연결하여 응답 확인
aws ssm start-session --target <test-server-2a-instance-id>
# 서버에서: curl localhost

aws ssm start-session --target <test-server-2c-instance-id>
# 서버에서: curl localhost
```

## 📁 프로젝트 구조

```
AWS_ALB_DOMAIN_ROUTING/
├── main.tf              # 메인 인프라 (VPC, EC2, ALB)
├── target_groups.tf     # ALB 타겟 그룹 및 연결
├── listeners.tf         # ALB 리스너 및 라우팅 규칙
├── outputs.tf          # 출력 값 및 테스트 명령어
├── variables.tf        # 입력 변수
├── .gitignore          # Git 무시 패턴
└── README.md           # 문서화
```

## 🔧 설정

### 변수

| 변수 | 설명 | 기본값 | 필수 |
|------|------|--------|------|
| `aws_region` | 배포할 AWS 리전 | `ap-northeast-2` | 아니오 |
| `instance_type` | EC2 인스턴스 타입 | `t3.micro` | 아니오 |
| `key_pair_name` | SSH 접근용 AWS 키 페어 | `eyjo-fnf-test-key` | 아니오 |

### 사용자 정의

사용자 정의 값을 위한 `terraform.tfvars` 파일 생성:

```hcl
aws_region = "us-west-2"
instance_type = "t3.small"
key_pair_name = "my-key-pair"
```

## 🏛️ 인프라 구성 요소

### 네트워크
- **VPC**: 10.0.0.0/16
- **퍼블릭 서브넷**: 10.0.1.0/24 (2a), 10.0.2.0/24 (2c)
- **프라이빗 서브넷**: 10.0.3.0/24 (2a), 10.0.4.0/24 (2c)
- **NAT 게이트웨이**: 비용 최적화를 위해 2a에 단일 NAT

### 보안
- **ALB 보안 그룹**: 인터넷에서 80, 443 포트
- **웹 보안 그룹**: ALB에서 80 포트, VPC에서 22 포트
- **API 보안 그룹**: ALB에서 8080 포트, VPC에서 22 포트
- **IAM 역할**: EC2 인스턴스용 SSM 접근

### 서비스
- **API 서버**: 8080 포트의 Node.js Express 서버 (2a 전용)
- **웹 서버**: 80 포트의 Apache HTTP 서버 (2a 전용)
- **테스트 서버**: 80 포트의 Apache HTTP 서버 (2a + 2c 멀티 AZ)
- **헬스 체크**: 서비스별 맞춤형 자동화된 헬스 모니터링

## 💰 Cost Considerations

### 현재 아키텍처
- **AZ 간 트래픽**: ALB 노드가 백엔드 타겟과 AZ 간 통신
- **멀티 AZ 백엔드**: 테스트 서버만 두 AZ에 배포, test.com 도메인 트래픽 분산
- **NAT 게이트웨이**: 모든 프라이빗 서브넷 인터넷 접근용 2a의 단일 NAT
- **인스턴스 시간**: 4개 t3.micro 인스턴스 (API + 웹 + 2개 테스트)

### 비용 최적화 옵션

1. **테스트 서버 단일 AZ로 변경** (테스트 기능 감소):
   ```hcl
   # test_server_2c 리소스 및 관련 타겟 그룹 연결 제거
   ```

2. **단일 AZ ALB** (가용성 감소, AZ 간 ALB 비용 제거):
   ```hcl
   subnets = [aws_subnet.public_subnet_2a.id]
   ```

3. **2c에 API/웹 서버 추가** (가용성 및 중복성 향상):
   ```hcl
   resource "aws_instance" "api_server_2c" { ... }
   resource "aws_instance" "web_server_2c" { ... }
   ```

## 🔄 확장성 및 확장 기능

### 오토 스케일링 추가

```hcl
resource "aws_autoscaling_group" "api_asg" {
  vpc_zone_identifier = [
    aws_subnet.private_subnet_2a.id,
    aws_subnet.private_subnet_2c.id  # 멀티 AZ 스케일링
  ]
  target_group_arns = [aws_lb_target_group.api_tg.arn]
  # ... 기타 설정
}
```

### HTTPS 지원 추가

```hcl
resource "aws_lb_listener" "https" {
  load_balancer_arn = aws_lb.domain_routing_alb.arn
  port              = "443"
  protocol          = "HTTPS"
  ssl_policy        = "ELBSecurityPolicy-TLS-1-2-2017-01"
  certificate_arn   = var.certificate_arn
  # ... 기타 설정
}
```

## 🔍 모니터링 및 문제 해결

### 서비스 상태 확인

```bash
# SSM을 통한 확인
aws ssm send-command \
  --instance-ids <instance-id> \
  --document-name "AWS-RunShellScript" \
  --parameters 'commands=["systemctl status api-server"]'

# ALB 헬스 체크를 통한 확인
aws elbv2 describe-target-health \
  --target-group-arn <target-group-arn>
```

### 멀티 AZ 로드 밸런싱 분석

```bash
# 각 테스트 서버의 접근 로그 확인
aws ssm start-session --target <test-server-2a-instance-id>
sudo tail -f /var/log/httpd/access_log

aws ssm start-session --target <test-server-2c-instance-id>
sudo tail -f /var/log/httpd/access_log

# API 서버 로그 확인
aws ssm start-session --target <api-server-instance-id>
sudo journalctl -u api-server -f
```

### 일반적인 문제

1. **503 Service Unavailable**: 타겟 그룹 헬스 확인
2. **Connection Timeout**: 보안 그룹 규칙 확인
3. **Wrong Service Response**: ALB 리스너 규칙 우선순위 확인
4. **Load Balancing Issues**: test.com 도메인 요청 시 멀티 AZ 분산 확인

## 🧹 정리

모든 리소스 삭제:

```bash
terraform destroy
```

**주의**: 생성된 모든 리소스가 영구적으로 삭제됩니다.

## 🤝 기여

1. 리포지토리 포크
2. 기능 브랜치 생성
3. 변경사항 적용
4. 충분한 테스트
5. 풀 리퀘스트 제출

## 📄 라이선스

이 프로젝트는 교육 및 시연 목적용입니다.

## 🆘 지원

문제 및 질문 시:
- AWS CloudWatch 로그 확인
- Terraform 상태 검토: `terraform show`
- 구성 검증: `terraform validate`

## 🎯 주요 학습 포인트

### 도메인 기반 라우팅
- **API 서비스**: api.example.com → Node.js API 서버 (2a)
- **웹 서비스**: www.example.com, example.com → Apache 웹 서버 (2a)
- **테스트 서비스**: test.com → 멀티 AZ 테스트 서버 (2a + 2c)
- **기본 라우팅**: 매치되지 않는 모든 도메인 → 기본 웹 서버 (2a)

### 멀티 AZ 아키텍처 장점
- **고가용성**: 복원력을 위해 여러 AZ에 ALB 배포
- **선택적 멀티 AZ**: test.com만 멀티 AZ 배포로 비용 최적화
- **서비스 분리**: 각 도메인별 독립적인 백엔드 서비스 운영
- **헬스 체크**: 서비스별 맞춤형 헬스 체크로 안정성 확보

---

**Terraform과 AWS로 ❤️ 제작**
**도메인 기반 라우팅 및 멀티 AZ ALB 데모를 위해 설계됨**