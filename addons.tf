# Addons gerenciados pela AWS. `resolve_conflicts_on_create = "OVERWRITE"` porque o
# EKS já sobe versões "self-managed" básicas de vpc-cni/kube-proxy/coredns junto com
# o cluster — sem isso, o Terraform falharia tentando criar algo que já existe.
resource "aws_eks_addon" "vpc_cni" {
  cluster_name                = aws_eks_cluster.this.name
  addon_name                  = "vpc-cni"
  resolve_conflicts_on_create = "OVERWRITE"
  resolve_conflicts_on_update = "OVERWRITE"
}

resource "aws_eks_addon" "kube_proxy" {
  cluster_name                = aws_eks_cluster.this.name
  addon_name                  = "kube-proxy"
  resolve_conflicts_on_create = "OVERWRITE"
  resolve_conflicts_on_update = "OVERWRITE"
}

resource "aws_eks_addon" "coredns" {
  cluster_name                = aws_eks_cluster.this.name
  addon_name                  = "coredns"
  resolve_conflicts_on_create = "OVERWRITE"
  resolve_conflicts_on_update = "OVERWRITE"

  # CoreDNS agenda pods em nós reais — sem isso o addon fica tentando (e podendo
  # falhar/demorar) por falta de nó disponível para o pod rodar.
  depends_on = [aws_eks_node_group.this]
}

# metrics-server: pré-requisito do HPA (`autoscaling/v2`, ver `k8s/hpa.yaml` e
# ADR-002 no repositório da aplicação) e citado como addon obrigatório na Etapa 3 do
# PHASE_3_PLAN.md.
#
# [DECISÃO] Helm em vez de `aws_eks_addon`: a partir de 03/2025 a AWS passou a
# oferecer metrics-server como "community addon" gerenciado, mas usá-lo via
# `aws_eks_addon` exigiria descobrir a versão compatível com `data.aws_eks_addon_version`
# (chamada de API — não verificável sem credenciais neste ambiente de
# desenvolvimento) e depende de uma versão do provider `hashicorp/aws` recente o
# bastante para o catálogo de community addons, não garantida dentro do range
# `~> 5.0` já fixado em versions.tf. O `helm_release` do chart oficial
# (kubernetes-sigs) funciona em qualquer versão do provider/cluster e é mais simples
# de depurar, ao custo de não aparecer como "addon gerenciado pela AWS" no console.
#
# Sem `version` fixada de propósito: não há como confirmar neste ambiente qual é a
# versão mais recente compatível no momento real do apply. Antes do primeiro apply
# de verdade, rodar `helm search repo metrics-server/metrics-server --versions` e
# fixar aqui.
resource "helm_release" "metrics_server" {
  name       = "metrics-server"
  repository = "https://kubernetes-sigs.github.io/metrics-server/"
  chart      = "metrics-server"
  namespace  = "kube-system"

  depends_on = [aws_eks_node_group.this]
}
