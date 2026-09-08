# Achado (2026-09-08): com `authenticationMode = CONFIG_MAP` (default do
# `aws_eks_cluster` sem `access_config`) e sem nenhum `aws-auth` ConfigMap
# gerenciado por este Terraform, só a identidade IAM que criou o cluster
# originalmente tem acesso via Kubernetes RBAC -- qualquer outra sessão
# (mesmo com credenciais AWS válidas) é tratada como `system:anonymous` pela
# API do cluster. Isso não afeta `kubectl` cru usado pelo pipeline da
# aplicação (nunca precisou ler recursos do cluster), mas quebra os
# providers `helm`/`kubernetes` deste repositório, que precisam ler Secrets
# em `kube-system` (onde o Helm guarda o estado das releases) mesmo só para
# planejar um apply sem mudanças -- ver erro real:
# `secrets is forbidden: User "system:anonymous" cannot list resource
# "secrets" in API group "" in the namespace "kube-system"`.
#
# Corrigido com o caminho recomendado pela AWS (EKS Access Entries), em vez
# de editar o `aws-auth` ConfigMap manualmente: `API_AND_CONFIG_MAP` é
# migração em runtime, sem recriar o cluster. `role/voclabs` é o papel
# assumido pela sessão federada do Learner Lab usada tanto localmente
# (`aws sts get-caller-identity`) quanto pelo CI (mesmas credenciais,
# publicadas por `scripts/refresh-aws-secrets.sh`) -- diferente da
# `var.lab_role_arn` (`LabRole`), que é o papel de EXECUÇÃO do cluster/nós,
# não de quem chama a API.
resource "aws_eks_access_entry" "voclabs" {
  cluster_name  = aws_eks_cluster.this.name
  principal_arn = "arn:aws:iam::442534931336:role/voclabs"
  type          = "STANDARD"
}

resource "aws_eks_access_policy_association" "voclabs_admin" {
  cluster_name  = aws_eks_cluster.this.name
  principal_arn = aws_eks_access_entry.voclabs.principal_arn
  policy_arn    = "arn:aws:eks::aws:cluster-access-policy/AmazonEKSClusterAdminPolicy"

  access_scope {
    type = "cluster"
  }
}
