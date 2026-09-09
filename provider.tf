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

# Dashboards e alertas (newrelic_dashboards.tf/newrelic_alerts.tf) -- sempre
# configurado, como os providers acima, mas inofensivo com account_id/api_key
# vazios porque todo resource que o usa é gated por var.enable_new_relic_dashboards.
provider "newrelic" {
  account_id = var.new_relic_account_id
  api_key    = var.new_relic_api_key
  region     = "US"
}
