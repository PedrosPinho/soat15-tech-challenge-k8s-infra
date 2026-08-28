# Tags de auto-descoberta de subnet exigidas pelo AWS Load Balancer Controller.
# Aplicadas aqui via `aws_ec2_tag` (recurso que adiciona/gerencia UMA tag, sem tomar
# posse do mapa de tags inteiro da subnet) em vez de no bloco `tags` da subnet no
# repositório db-infra — assim cada repositório só declara a tag que precisa, sem
# os dois states competirem pelo mesmo atributo do mesmo recurso.
resource "aws_ec2_tag" "public_subnet_cluster" {
  for_each    = toset(data.terraform_remote_state.db_infra.outputs.public_subnet_ids)
  resource_id = each.value
  key         = "kubernetes.io/cluster/${aws_eks_cluster.this.name}"
  value       = "shared"
}

resource "aws_ec2_tag" "public_subnet_elb" {
  for_each    = toset(data.terraform_remote_state.db_infra.outputs.public_subnet_ids)
  resource_id = each.value
  key         = "kubernetes.io/role/elb"
  value       = "1"
}

# Subnets privadas: sem nós hoje (cluster e node group inteiros nas subnets
# públicas — ver eks.tf), mas já tagueadas para o NLB interno que a Etapa 2 do
# PHASE_3_PLAN.md (VPC Link do API Gateway, repositório auth-lambda) vai precisar
# criar. Evita repetir esta decisão de tagging num repositório futuro.
resource "aws_ec2_tag" "private_subnet_cluster" {
  for_each    = toset(data.terraform_remote_state.db_infra.outputs.private_subnet_ids)
  resource_id = each.value
  key         = "kubernetes.io/cluster/${aws_eks_cluster.this.name}"
  value       = "shared"
}

resource "aws_ec2_tag" "private_subnet_internal_elb" {
  for_each    = toset(data.terraform_remote_state.db_infra.outputs.private_subnet_ids)
  resource_id = each.value
  key         = "kubernetes.io/role/internal-elb"
  value       = "1"
}

# AWS Load Balancer Controller via Helm (chart `aws-load-balancer-controller` do
# repositório `eks-charts`). Sem annotation de IRSA no ServiceAccount — não existe
# OIDC provider neste cluster (ADR-006). O pod herda a LabRole pelo instance profile
# do nó via IMDS, do mesmo jeito que qualquer outro pod do cluster; por isso
# `vpcId`/`region` são passados explicitamente em vez de depender de
# auto-detecção (que também usa IMDS, mas é mais frágil de depurar quando falha).
#
# Sem `version` fixada pelo mesmo motivo do metrics-server (addons.tf): confirmar
# a versão compatível com `helm search repo eks/aws-load-balancer-controller
# --versions` antes do primeiro apply de verdade e fixar aqui.
resource "helm_release" "aws_load_balancer_controller" {
  name       = "aws-load-balancer-controller"
  repository = "https://aws.github.io/eks-charts"
  chart      = "aws-load-balancer-controller"
  namespace  = "kube-system"

  set {
    name  = "clusterName"
    value = aws_eks_cluster.this.name
  }

  set {
    name  = "region"
    value = var.aws_region
  }

  set {
    name  = "vpcId"
    value = data.terraform_remote_state.db_infra.outputs.vpc_id
  }

  set {
    name  = "serviceAccount.create"
    value = "true"
  }

  set {
    name  = "serviceAccount.name"
    value = "aws-load-balancer-controller"
  }

  depends_on = [
    aws_eks_node_group.this,
    aws_eks_addon.vpc_cni,
  ]
}
