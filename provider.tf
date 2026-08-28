provider "aws" {
  region = var.aws_region

  default_tags {
    tags = {
      Project     = "soat15-tech-challenge"
      Repository  = "k8s-infra"
      Environment = terraform.workspace
      ManagedBy   = "terraform"
    }
  }
}

# Configurados como data sources no módulo do cluster (aws_eks_cluster_auth), não
# aqui, para não exigir o cluster já existir só para carregar o provider.
