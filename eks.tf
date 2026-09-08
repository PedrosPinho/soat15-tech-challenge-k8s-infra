# Cluster EKS.
#
# Subnets: PÚBLICAS, não privadas — decisão do repositório db-infra (sem NAT Gateway
# na VPC, para caber no orçamento do Learner Lab). Sem NAT, nós em subnet privada não
# alcançariam ECR/API do EKS/etc.; por isso tanto o control plane quanto o node group
# (node_group.tf) usam as subnets públicas exportadas por db-infra, com o tráfego
# controlado por security group em vez de isolamento de rede por subnet.
#
# Role: LabRole compartilhada (var.lab_role_arn) — o Learner Lab bloqueia IAM, então
# não há como criar uma role dedicada ao cluster com só as policies mínimas
# (AmazonEKSClusterPolicy etc.). Ver ADR-006 no repositório da aplicação.
resource "aws_eks_cluster" "this" {
  name     = "${var.project_name}-cluster"
  role_arn = var.lab_role_arn
  version  = var.cluster_version

  vpc_config {
    subnet_ids              = data.terraform_remote_state.db_infra.outputs.public_subnet_ids
    endpoint_private_access = true
    endpoint_public_access  = true
  }

  # API_AND_CONFIG_MAP (não API puro): migração aditiva, mantém compatibilidade
  # com o que já dependia do modo CONFIG_MAP default, e permite gerenciar
  # acesso via EKS Access Entries (ver eks_access.tf) em vez do aws-auth
  # ConfigMap manual.
  access_config {
    authentication_mode = "API_AND_CONFIG_MAP"
  }
}

# --- Providers Kubernetes/Helm ----------------------------------------------------
# Configurados aqui (não em provider.tf) porque dependem do cluster já existir — ver
# o comentário deixado em provider.tf sobre isso. Autenticação via
# `aws_eks_cluster_auth`, que assina um token curto usando as credenciais AWS do
# apply — não depende de kubeconfig local nem de aws-auth ConfigMap.
data "aws_eks_cluster_auth" "this" {
  name = aws_eks_cluster.this.name
}

provider "kubernetes" {
  host                   = aws_eks_cluster.this.endpoint
  cluster_ca_certificate = base64decode(aws_eks_cluster.this.certificate_authority[0].data)
  token                  = data.aws_eks_cluster_auth.this.token
}

provider "helm" {
  kubernetes {
    host                   = aws_eks_cluster.this.endpoint
    cluster_ca_certificate = base64decode(aws_eks_cluster.this.certificate_authority[0].data)
    token                  = data.aws_eks_cluster_auth.this.token
  }
}
