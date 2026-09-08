# Launch template custom só para anexar, além do security group que o próprio
# cluster gera automaticamente, o security group customizado exportado por db-infra
# (`eks_nodes_security_group_id`) às instâncias dos nós. É esse SG customizado — não
# o `cluster_security_group_id` gerado pelo EKS — que a regra de ingress do RDS libera
# na porta 5432 (ver db-infra). Um managed node group sem launch template só recebe o
# SG automático do cluster, que o RDS não conhece; por isso o launch template aqui
# lista os dois.
resource "aws_launch_template" "nodes" {
  name_prefix = "${var.project_name}-node-"

  vpc_security_group_ids = [
    aws_eks_cluster.this.vpc_config[0].cluster_security_group_id,
    data.terraform_remote_state.db_infra.outputs.eks_nodes_security_group_id,
  ]

  tag_specifications {
    resource_type = "instance"
    tags = {
      Name = "${var.project_name}-node"
    }
  }

  lifecycle {
    create_before_destroy = true
  }
}

# Node group gerenciado. Subnets públicas e node role = LabRole pelo mesmo motivo do
# cluster (eks.tf) — ver ADR-006. `instance_types` fica no node group (não no launch
# template) de propósito: os dois não podem definir o tipo de instância ao mesmo
# tempo.
resource "aws_eks_node_group" "this" {
  cluster_name    = aws_eks_cluster.this.name
  node_group_name = "${var.project_name}-nodes"
  node_role_arn   = var.lab_role_arn
  subnet_ids      = data.terraform_remote_state.db_infra.outputs.public_subnet_ids

  instance_types = [var.node_instance_type]
  ami_type       = "AL2023_x86_64_STANDARD"

  scaling_config {
    min_size     = var.node_min_size
    max_size     = var.node_max_size
    desired_size = var.node_min_size
  }

  update_config {
    max_unavailable = 1
  }

  launch_template {
    id      = aws_launch_template.nodes.id
    version = aws_launch_template.nodes.latest_version
  }

  depends_on = [aws_launch_template.nodes]
}
