# Mesmo bucket/tabela de estado do repositório db-infra, key própria deste repo.
terraform {
  backend "s3" {
    bucket         = "soat15-tc-tfstate-442534931336"
    key            = "k8s-infra/terraform.tfstate"
    region         = "us-east-1"
    dynamodb_table = "soat15-tc-tfstate-lock"
    encrypt        = true
  }
}
