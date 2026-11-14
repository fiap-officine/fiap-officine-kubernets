# ☸️ fiap-officine-kubernets — Infraestrutura Base AWS, Kubernetes & API Gateway

**Tech Challenge FIAP (15SOAT)**  
Repositório responsável pelo provisionamento e gerenciamento da **Infraestrutura Base na AWS** via **Terraform** para o ecossistema **fiap-officine**. Atua como a fundação de rede, segurança e orquestração de microsserviços de toda a plataforma.

---


## Fase 4 — plataforma compartilhada dos microsserviços

| Mudança | Onde |
|---|---|
| ECR com um repositório por serviço (`fiap-officine-os-service`, `-billing-service`, `-execution-service`) | `environments/homolog/main.tf` (`module "ecr"`) — repositórios são da conta, por isso criados só uma vez |
| Rotas públicas (sem authorizer): `POST /api/v1/pagamentos/webhook` (Mercado Pago, validado por `x-signature`), `GET /internal/clientes/status/{cpf}` (Lambda, validado por `x-internal-token`), docs/health do Billing e do Execution | `modules/api_gateway/main.tf` (`aws_apigatewayv2_route.public_backend`) |
| IMDSv2 com `http_put_response_hop_limit = 2` para os pods usarem o instance profile (SQS/DynamoDB sem access keys) | `modules/k3s/main.tf` |
| Output `k3s_node_role_name`: cada microsserviço anexa a sua política IAM nessa role (`node_role_name` no Terraform do serviço) | `modules/k3s/outputs.tf` |

| State remoto no S3 (`fiap-officine-tfstate-<account_id>`, criado pelo próprio workflow) | `environments/homolog/main.tf` + `.github/workflows/terraform.yml` |
| AMI Ubuntu 24.04 da Canonical buscada na região (sem ID fixo de outra conta) | `modules/k3s/main.tf` (`data "aws_ami"`) |
| Elastic IP no nó; o nó publica o kubeconfig (com esse IP) no SSM e os pipelines de deploy leem de lá | `modules/k3s/main.tf` (`aws_eip`, `user_data`) |
| RDS acessível a partir do nó K3s (regra de entrada 5432) | `environments/homolog/main.tf` (`aws_security_group_rule.rds_from_k3s`) |
| Lambda de auth e authorizer ligadas automaticamente ao API Gateway quando já existem | `environments/homolog/main.tf` (`data "aws_lambda_functions"`) |
| Parâmetros compartilhados no SSM (`/fiap-officine/homolog/...`): URL do API Gateway, role do nó, IP público, VPC, SG e subnet group do RDS | `environments/homolog/main.tf` (`aws_ssm_parameter.shared`) |

### Subindo o ambiente numa conta AWS nova

Pré-requisito: secrets `AWS_ACCESS_KEY_ID` e `AWS_SECRET_ACCESS_KEY` na organização
(usuário IAM do CI). Ordem dos merges em `develop` (cada merge dispara o apply):

1. **fiap-officine-kubernets** — VPC, nó K3s, API Gateway, ECR e parâmetros no SSM.
   O nó leva ~5 min para instalar o K3s e publicar `/fiap-officine/homolog/k3s/kubeconfig`.
2. **fiap-officine-database** — RDS PostgreSQL; publica endpoint e credenciais master
   (`/fiap-officine/homolog/rds/*`, senha como SecureString).
3. **fiap-officine-os-service**, **-billing-service**, **-execution-service** — o
   `infra.yml` cria filas, tabelas e IAM; o `ci-cd.yml` publica a imagem no ECR, cria os
   bancos lógicos e faz o deploy lendo kubeconfig/RDS/API Gateway do SSM.
4. **fiap-officine-lambda** — Lambda de auth e authorizer (URL do os-service lida do SSM).
5. **Rodar de novo o workflow deste repositório** (Actions → *Re-run jobs*) para ligar
   a Lambda (`/auth/login`) e o authorizer (`$default`) ao API Gateway.

> O nó usa um **Elastic IP**: parar e iniciar a instância (para economizar fora das
> demos) não muda o endereço do API Gateway nem invalida o kubeconfig.

O Traefik roteia por path para cada Service (`/api/v1/ordens-servico` → os-service,
`/api/v1/orcamentos|pagamentos` → billing-service, `/api/v1/execucoes|estoque` →
execution-service); cada repositório publica o seu Ingress no namespace `officine`.

> **Capacidade:** o nó é um **t3.medium (4 GiB)**. No t3.micro (1 GiB + 2 GiB de
> swap) o nó ficou *NotReady* com os três serviços durante os deploys (o rolling
> update sobe um pod a mais). Para economizar, pare a instância fora das demos: o
> Elastic IP mantém o endereço.

## 🎯 Propósito do Repositório

O **fiap-officine-kubernets** gerencia e automatiza a infraestrutura de nuvem na AWS:
* **Rede Isolada (VPC Multi-AZ)**: Provisionamento de subnets Públicas, Privadas e de Banco de Dados distribuídas entre 3 zonas de disponibilidade (`us-east-2a`, `us-east-2b`, `us-east-2c`).
* **Segurança de Borda (Security Groups)**: Regras estritas de firewall isolando o RDS PostgreSQL, a Function Serverless (Lambda), os nós do Kubernetes e o API Gateway.
* **Orquestração de Microsserviços**: Provisionamento de nó Kubernetes **K3s (Free Tier)** para homologação e **Amazon EKS** para produção.
* **Ponto Único de Entrada (AWS API Gateway HTTP API v2)**:
  - Rotas públicas abertas para visualização e observabilidade (`/docs`, `/openapi.json`, `/redoc`, `/health`, `/api/v1/health`).
  - Rota de autenticação serverless (`/auth/login`).
  - Proteção de todas as rotas de negócio (`$default`) via **Lambda Authorizer** com validação de JWT.

---

## 🏗️ Diagrama da Arquitetura do Repositório

```mermaid
graph TD
    subgraph INTERNET["Internet Pública"]
        CLIENT["Cliente / Navegador / Postman"]
    end

    subgraph AWS_CLOUD["AWS Cloud — Região us-east-2"]
        APIGW["AWS API Gateway HTTP API v2\n(https://kai652jumh.execute-api.us-east-2.amazonaws.com)"]

        subgraph VPC["VPC 10.0.0.0/16 (fiap-officine-homolog)"]
            subgraph PUBLIC_SUBNETS["Public Subnets (10.0.1.0/24, 10.0.2.0/24, 10.0.3.0/24)"]
                IGW["Internet Gateway"]
                K3S["Nó Kubernetes K3s (EC2 t3.micro)\nIP: 54.232.242.171 | SG: k3s-sg\nIngress Traefik (Porta 80)"]
            end

            subgraph PRIVATE_SUBNETS["Private Subnets (10.0.11.0/24, 10.0.12.0/24, 10.0.13.0/24)"]
                LAMBDA_AUTH["Auth Lambda (Repo fiap-officine-lambda)\nSG: lambda-sg"]
                LAMBDA_AUTHZ["Lambda Authorizer (Validação JWT)"]
            end

            subgraph DATABASE_SUBNETS["Database Subnets (10.0.21.0/24, 10.0.22.0/24, 10.0.23.0/24)"]
                RDS[("AWS RDS PostgreSQL 16.9\n(Repo fiap-officine-database)\nSG: rds-sg")]
            end
        end
    end

    %% Rotas do API Gateway
    CLIENT -->|"GET /docs, /openapi.json, /health"| APIGW
    CLIENT -->|"POST /auth/login (CPF)"| APIGW
    CLIENT -->|"ANY /api/v1/* (Bearer JWT)"| APIGW

    %% Roteamentos
    APIGW -->|"Rota Pública (NONE)"| K3S
    APIGW -->|"Rota Pública /auth/login (AWS_PROXY)"| LAMBDA_AUTH
    APIGW -.->|"Authorizer REQUEST (Cache 300s)"| LAMBDA_AUTHZ
    APIGW -->|"Rota Protegida $default (Proxy HTTP)"| K3S

    %% Conectividade interna
    LAMBDA_AUTH -->|"Porta 5432"| RDS
    K3S -->|"Porta 5432"| RDS
```

---

## 🚀 Tecnologias Utilizadas

| Tecnologia | Uso |
| :--- | :--- |
| **Terraform 1.9+** | Infraestrutura como Código (IaC) modular e reutilizável |
| **AWS API Gateway (HTTP API v2)** | Gateway gerenciado de baixa latência, suporte nativo a CORS e Lambda Authorizer |
| **AWS VPC & Security Groups** | Arquitetura de rede isolada em 3 AZs com subnets públicas, privadas e de dados |
| **K3s (Lightweight Kubernetes)** | Orquestrador Kubernetes leve e 100% elegível ao Free Tier para homologação |
| **Amazon EKS** | Orquestrador Kubernetes gerenciado para ambientes produtivos de alta escala |
| **Traefik Ingress Controller** | Ingress controller integrado nativamente ao nó K3s para proxy reverso |
| **AWS Systems Manager (SSM)** | Acesso shell seguro aos nós sem portas SSH expostas ou necessidade de chaves `.pem` |
| **GitHub Actions** | Validação sintática, formatação, planejamento e deploy contínuo |

---

## 📡 Documentação das APIs (Swagger & Postman)

O API Gateway provisionado por este repositório expõe diretamente os seguintes endpoints públicos para visualização e testes:

* **Swagger UI (Documentação Interativa)**:  
  👉 [https://kai652jumh.execute-api.us-east-2.amazonaws.com/docs](https://kai652jumh.execute-api.us-east-2.amazonaws.com/docs)
* **ReDoc (Documentação Técnica)**:  
  👉 [https://kai652jumh.execute-api.us-east-2.amazonaws.com/redoc](https://kai652jumh.execute-api.us-east-2.amazonaws.com/redoc)
* **Contrato OpenAPI JSON (Postman / Swagger Editor)**:  
  👉 [https://kai652jumh.execute-api.us-east-2.amazonaws.com/openapi.json](https://kai652jumh.execute-api.us-east-2.amazonaws.com/openapi.json)
* **Healthcheck de Uptime**:  
  👉 [https://kai652jumh.execute-api.us-east-2.amazonaws.com/health](https://kai652jumh.execute-api.us-east-2.amazonaws.com/health)
* **Healthcheck Detalhado (DB + Cache)**:  
  👉 [https://kai652jumh.execute-api.us-east-2.amazonaws.com/api/v1/health](https://kai652jumh.execute-api.us-east-2.amazonaws.com/api/v1/health)

### 🔐 Comportamento de Acesso e Códigos de Retorno das Rotas

| Tipo de Rota | Endpoints | Autorização | Comportamento e Resposta |
| :--- | :--- | :--- | :--- |
| **Públicas** | `/health`, `/docs`, `/openapi.json`, `/redoc` | Nenhuma (`NONE`) | `200 OK` (retorna `503 Service Unavailable` apenas em janelas transitórias de reinicialização/cold start do nó EC2 Free Tier) |
| **Autenticação** | `POST /auth/login` | Nenhuma (Valida CPF no RDS) | `200 OK` contendo o `access_token` JWT emitido pela Lambda |
| **Protegidas** | `/api/v1/ordens-servico/*`, `/api/v1/clientes/*`, etc. | **Bearer JWT Obrigatório** | • **Sem Token ou Inválido**: `401 Unauthorized` (bloqueado pelo **Lambda Authorizer** de borda antes de alcançar o nó Kubernetes)<br>• **Com Token Válido**: `200 OK` / `201 Created` processado pelos pods da API |

---

## 🛠️ Estrutura de Módulos Terraform

```
fiap-officine-kubernets/
├── terraform/
│   ├── modules/
│   │   ├── vpc/                      # VPC, Subnets Públicas/Privadas/Database, IGW e Route Tables
│   │   ├── security_groups/          # Security Groups: alb, k3s, lambda, rds
│   │   ├── k3s/                      # Nó EC2 K3s Free Tier (t3.micro) com 2GB Swap e SSM
│   │   ├── eks/                      # Cluster EKS Gerenciado (para Produção)
│   │   └── api_gateway/              # HTTP API v2 com rotas públicas (/docs, /health) e Authorizer
│   └── environments/
│       ├── homolog/                  # Ambiente 100% Free Tier ($0 de custo fixo)
│       └── production/               # Ambiente Multi-AZ com EKS
└── .github/workflows/
    └── terraform.yml                 # Pipeline CI/CD com validação, plan e apply
```

---

## 💰 Comparativo de Ambientes

| Componente | Homologação (100% Free Tier) | Produção (Alta Disponibilidade) |
| :--- | :--- | :--- |
| **Orquestrador K8s** | **K3s em EC2 `t3.micro`** ($0.00 / 750h mês) | **AWS EKS Gerenciado** (Multi-AZ) |
| **NAT Gateway** | **Desabilitado ($0 custo)** | 2 a 3 NAT Gateways redundantes |
| **API Gateway** | **HTTP API v2** (1 milhão req/mês grátis) | HTTP API v2 com CloudFront / Custom Domain |
| **Conexão Shell** | **AWS SSM Session Manager** (Zero chave SSH) | AWS SSM Session Manager com auditoria IAM |
| **Custo Fixo Estimado** | **$0.00 / mês** | ~$80 a $150 / mês |

---

## 🚀 Como Executar e Aplicar a Infraestrutura

### 1. Inicializar e Planejar Homologação:
```bash
cd terraform/environments/homolog
terraform init
terraform plan
```

### 2. Aplicar as Alterações na AWS:
```bash
terraform apply -auto-approve
```

### 3. Conectar ao Terminal do Nó Kubernetes via AWS SSM (Sem Chave SSH):
```bash
aws ssm start-session --target i-0484adf59b70f850f --region us-east-2
```

---

## 🛰️ Recursos Ativos em Homologação (AWS us-east-2)

* **VPC ID**: `vpc-074f1e84d85d2f999`
* **API Gateway ID**: `kai652jumh`
* **URL Pública do API Gateway**: `https://kai652jumh.execute-api.us-east-2.amazonaws.com`
* **Instância K3s**: `i-0484adf59b70f850f` (IP: `54.232.242.171`)
* **Security Group da Lambda**: `sg-099bc9a0635f1d4a6`
* **Security Group do RDS**: `sg-0faf87d7a9a816a46`

---

## 🔒 Governança de Branches
* **Branch `main` e `develop` protegidas** contra commits diretos.
* **Obrigatório uso de Pull Requests** com validação compulsória de `terraform fmt`, `terraform validate` e `terraform plan`.
* **Deploy contínuo**: Merge em `develop` ➔ Deploy em Homologação; Merge em `main` ➔ Deploy em Produção.