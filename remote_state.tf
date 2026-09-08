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
