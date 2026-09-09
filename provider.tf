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

# Dashboards e alertas (newrelic_dashboards.tf/newrelic_alerts.tf) -- diferente
# dos providers aws/kubernetes/helm acima, o newrelic-client-go valida a
# presença de uma API key já no Configure, mesmo sem nenhum resource usá-la
# (quebrou o apply inteiro do repositório antes dos secrets existirem, apesar
# de tudo que a usa estar com count=0). Sem placeholder aqui, var.enable_new_relic_dashboards
# não teria como ser "false com segurança" como os outros flags do mesmo padrão.
provider "newrelic" {
  account_id = var.new_relic_account_id
  api_key    = var.new_relic_api_key != "" ? var.new_relic_api_key : "NRAK-PLACEHOLDER00000000000000000"
  region     = "US"
}
