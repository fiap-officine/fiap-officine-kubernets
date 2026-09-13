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
resource "aws_instance" "k3s" {
  ami           = var.ami_id
  instance_type = var.instance_type
  subnet_id     = var.subnet_id

  associate_public_ip_address = true
  iam_instance_profile        = aws_iam_instance_profile.k3s.name
  vpc_security_group_ids      = [aws_security_group.k3s.id]
  key_name                    = var.key_name

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
              TOKEN=$(curl -s -X PUT "http://169.254.169.254/latest/api/token" -H "X-aws-ec2-metadata-token-ttl-seconds: 21600")
              PUBLIC_IP=$(curl -s -H "X-aws-ec2-metadata-token: $TOKEN" http://169.254.169.254/latest/meta-data/public-ipv4 || curl -s https://api.ipify.org)

              # 3. Instalar K3s com suporte a TLS no IP público
              curl -sfL https://get.k3s.io | INSTALL_K3S_EXEC="server --tls-san $PUBLIC_IP --write-kubeconfig-mode 644" sh -

              # 4. Configurar kubeconfig para o usuário ubuntu e root
              mkdir -p /home/ubuntu/.kube
              cp /etc/rancher/k3s/k3s.yaml /home/ubuntu/.kube/config
              chown -R ubuntu:ubuntu /home/ubuntu/.kube
              chmod 600 /home/ubuntu/.kube/config
              EOF

  tags = merge(var.tags, {
    Name = "${var.name}-k3s-server"
  })

  lifecycle {
    ignore_changes = [ami]
  }
}
