# Outputs de db-infra: VPC e subnets já provisionadas por lá (ver ADR-003 no repo
# da aplicação — VPC vive no repositório de banco por ser o primeiro a precisar
# de subnets privadas).
data "terraform_remote_state" "db_infra" {
  backend   = "s3"
  workspace = "homolog"

  config = {
    bucket = "soat15-tc-tfstate-442534931336"
    key    = "db-infra/terraform.tfstate"
    region = "us-east-1"
  }
}

# Endpoint público do API Gateway (auth-lambda), só para o Synthetics monitor
# de healthcheck em newrelic_alerts.tf -- mesma convenção de ler o workspace
# homolog acima (é o ambiente ao vivo de fato usado na demonstração).
data "terraform_remote_state" "auth_lambda" {
  backend   = "s3"
  workspace = "homolog"

  config = {
    bucket = "soat15-tc-tfstate-442534931336"
    key    = "auth-lambda/terraform.tfstate"
    region = "us-east-1"
  }
}
