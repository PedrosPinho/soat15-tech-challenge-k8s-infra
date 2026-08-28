# Repositório ECR da imagem da API. `force_delete = true` de propósito: o ciclo
# destroy/apply por sessão do Learner Lab (ver README) precisa conseguir destruir o
# repositório mesmo com imagens dentro — o padrão (`force_delete = false`) travaria o
# `terraform destroy` no fim de toda sessão de trabalho.
resource "aws_ecr_repository" "api" {
  name                 = var.ecr_repository_name
  image_tag_mutability = "MUTABLE"
  force_delete         = true

  image_scanning_configuration {
    scan_on_push = true
  }
}

# Mantém só as últimas ~10 imagens — evita acumular custo de storage do ECR ao
# longo das sessões (o repositório em si sobrevive ao destroy/apply do resto da
# infra, então imagens antigas se acumulariam indefinidamente sem isso).
resource "aws_ecr_lifecycle_policy" "api" {
  repository = aws_ecr_repository.api.name

  policy = jsonencode({
    rules = [
      {
        rulePriority = 1
        description  = "Manter apenas as ultimas 10 imagens"
        selection = {
          tagStatus   = "any"
          countType   = "imageCountMoreThan"
          countNumber = 10
        }
        action = {
          type = "expire"
        }
      }
    ]
  })
}
