# ──────────────────────────────────────────────
# IAM Role para o Nó K3s
# ──────────────────────────────────────────────
data "aws_iam_policy_document" "ec2_assume_role" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "k3s" {
  name_prefix        = "${var.name}-k3s-role-"
  assume_role_policy = data.aws_iam_policy_document.ec2_assume_role.json

  tags = var.tags

  lifecycle {
    create_before_destroy = true
  }
}

# Permissões: SSM (Acesso ao terminal sem SSH) + ECR (Puxar imagens sem credenciais)
resource "aws_iam_role_policy_attachment" "ssm" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
  role       = aws_iam_role.k3s.name
}

# Permite ao nó publicar o próprio kubeconfig no SSM (lido pelos pipelines de deploy)
data "aws_caller_identity" "current" {}

resource "aws_iam_role_policy" "publish_kubeconfig" {
  name = "publish-kubeconfig"
  role = aws_iam_role.k3s.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect   = "Allow"
      Action   = ["ssm:PutParameter"]
      Resource = "arn:aws:ssm:${data.aws_region.current.region}:${data.aws_caller_identity.current.account_id}:parameter${var.ssm_parameter_prefix}/k3s/*"
    }]
  })
}

resource "aws_iam_role_policy_attachment" "ecr_readonly" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
  role       = aws_iam_role.k3s.name
}

resource "aws_iam_instance_profile" "k3s" {
  name_prefix = "${var.name}-k3s-profile-"
  role        = aws_iam_role.k3s.name

  tags = var.tags
}

# ──────────────────────────────────────────────
# Security Group do Nó K3s
# ──────────────────────────────────────────────
resource "aws_security_group" "k3s" {
  name_prefix = "${var.name}-k3s-sg-"
  description = "Security group for K3s lightweight Kubernetes node"
  vpc_id      = var.vpc_id

  # Kubernetes API
  ingress {
    description = "Kubernetes API Server"
    from_port   = 6443
    to_port     = 6443
    protocol    = "tcp"
    cidr_blocks = var.allowed_k8s_api_cidrs
  }

  # HTTP
  ingress {
    description = "HTTP application traffic"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # HTTPS
  ingress {
    description = "HTTPS application traffic"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # SSH (opcional, gerenciado via SSM)
  ingress {
    description = "SSH access"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # Saída irrestrita para a internet (via Internet Gateway, $0 custo)
  egress {
    description = "Allow all outbound traffic"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(var.tags, {
    Name = "${var.name}-k3s-sg"
  })

  lifecycle {
    create_before_destroy = true
  }
}

# ──────────────────────────────────────────────
# Instância EC2: Nó K3s (Free Tier)
# ──────────────────────────────────────────────
# Ubuntu 24.04 LTS (Canonical) mais recente na região: evita AMI fixa de outra conta/região
data "aws_ami" "ubuntu" {
  most_recent = true
  owners      = ["099720109477"]

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd-gp3/ubuntu-noble-24.04-amd64-server-*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

# Elastic IP: endereço estável para o API Gateway, o kubeconfig e o TLS do K3s
resource "aws_eip" "k3s" {
  domain = "vpc"

  tags = merge(var.tags, {
    Name = "${var.name}-k3s-eip"
  })
}

resource "aws_eip_association" "k3s" {
  instance_id   = aws_instance.k3s.id
  allocation_id = aws_eip.k3s.id
}

resource "aws_instance" "k3s" {
  ami           = var.ami_id != null ? var.ami_id : data.aws_ami.ubuntu.id
  instance_type = var.instance_type
  subnet_id     = var.subnet_id

  associate_public_ip_address = true
  iam_instance_profile        = aws_iam_instance_profile.k3s.name
  vpc_security_group_ids      = [aws_security_group.k3s.id]
  key_name                    = var.key_name

  # IMDSv2 com hop limit 2: os pods (1 salto extra de rede) conseguem obter as
  # credenciais do instance profile para acessar SQS/DynamoDB sem access keys.
  metadata_options {
    http_endpoint               = "enabled"
    http_tokens                 = "required"
    http_put_response_hop_limit = 2
  }

  root_block_device {
    volume_size           = var.disk_size
    volume_type           = "gp3"
    encrypted             = true
    delete_on_termination = true
    tags = merge(var.tags, {
      Name = "${var.name}-k3s-disk"
    })
  }

  user_data = <<-EOF
              #!/bin/bash
              set -e

              # 1. Configurar 2GB de Swap imediatamente para evitar OOM no t3.micro
              fallocate -l 2G /swapfile
              chmod 600 /swapfile
              mkswap /swapfile
              swapon /swapfile
              echo '/swapfile none swap sw 0 0' >> /etc/fstab

              # 2. Obter IP público do metadata service (IMDSv2)
              # Elastic IP fixo (conhecido antes da criação da instância): o
              # certificado do K3s e o kubeconfig continuam válidos após stop/start
              PUBLIC_IP=${aws_eip.k3s.public_ip}
              # Espera a associação do Elastic IP (troca o IP de saída) antes de baixar o K3s
              TOKEN=$(curl -s -X PUT "http://169.254.169.254/latest/api/token" -H "X-aws-ec2-metadata-token-ttl-seconds: 21600")
              for attempt in $(seq 1 60); do
                CURRENT_IP=$(curl -s -H "X-aws-ec2-metadata-token: $TOKEN" http://169.254.169.254/latest/meta-data/public-ipv4 || true)
                [ "$CURRENT_IP" = "$PUBLIC_IP" ] && break
                sleep 5
              done

              # 3. Instalar K3s com suporte a TLS no IP público
              curl -sfL https://get.k3s.io | INSTALL_K3S_EXEC="server --tls-san $PUBLIC_IP --write-kubeconfig-mode 644" sh -

              # 4. Configurar kubeconfig para o usuário ubuntu e root
              mkdir -p /home/ubuntu/.kube
              cp /etc/rancher/k3s/k3s.yaml /home/ubuntu/.kube/config
              chown -R ubuntu:ubuntu /home/ubuntu/.kube
              chmod 600 /home/ubuntu/.kube/config

              # Publica o kubeconfig (com o IP público) no SSM para os pipelines de deploy
              until [ -s /etc/rancher/k3s/k3s.yaml ]; do sleep 2; done
              sed "s#https://127.0.0.1:6443#https://$PUBLIC_IP:6443#" /etc/rancher/k3s/k3s.yaml > /root/kubeconfig-public.yaml
              snap install aws-cli --classic
              for attempt in $(seq 1 30); do
                /snap/bin/aws ssm put-parameter \
                  --region ${data.aws_region.current.region} \
                  --name "${var.ssm_parameter_prefix}/k3s/kubeconfig" \
                  --type SecureString --tier Intelligent-Tiering --overwrite \
                  --value file:///root/kubeconfig-public.yaml && break
                sleep 10
              done
              EOF

  tags = merge(var.tags, {
    Name = "${var.name}-k3s-server"
  })

  lifecycle {
    ignore_changes = [ami]
  }
}
