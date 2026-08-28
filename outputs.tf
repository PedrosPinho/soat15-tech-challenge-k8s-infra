output "cluster_name" {
  description = "Nome do cluster EKS"
  value       = aws_eks_cluster.this.name
}

output "cluster_endpoint" {
  description = "Endpoint da API do cluster EKS"
  value       = aws_eks_cluster.this.endpoint
}

output "cluster_certificate_authority_data" {
  description = "CA (base64) do cluster EKS, para configurar kubeconfig/providers em outros repositórios"
  value       = aws_eks_cluster.this.certificate_authority[0].data
}

output "ecr_repository_url" {
  description = "URL do repositório ECR da imagem da API"
  value       = aws_ecr_repository.api.repository_url
}

# Atenção ao nome: este É o security group que o próprio EKS cria e gerencia
# automaticamente para o cluster/nós (`vpc_config[0].cluster_security_group_id`).
# NÃO é o mesmo recurso que `eks_nodes_security_group_id`, exportado pelo
# repositório db-infra — aquele é um SG customizado, criado em db-infra
# especificamente para ser referenciado na regra de ingress do RDS (porta 5432) e
# anexado aos nós via launch template (ver node_group.tf). Os dois SGs convivem nas
# instâncias dos nós ao mesmo tempo; este output existe só para quem precisar
# referenciar o SG "nativo" do cluster (ex.: regras de ingress adicionais no próprio
# cluster), não para a integração com o RDS.
output "node_security_group_id" {
  description = "SG gerado automaticamente pelo EKS para o cluster/nós (cluster_security_group_id) — distinto do SG customizado eks_nodes_security_group_id de db-infra, usado na regra de ingress do RDS"
  value       = aws_eks_cluster.this.vpc_config[0].cluster_security_group_id
}
