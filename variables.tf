variable "aws_region" {
  description = "Região AWS (fixa, restrição do Learner Lab)"
  type        = string
  default     = "us-east-1"
}

variable "lab_role_arn" {
  description = "ARN da LabRole pré-criada pelo AWS Academy Learner Lab (sem IRSA — ver ADR-006)"
  type        = string
  default     = "arn:aws:iam::442534931336:role/LabRole"
}

variable "project_name" {
  description = "Prefixo usado no nome dos recursos"
  type        = string
  default     = "soat15-tc"
}

variable "cluster_version" {
  description = "Versão do Kubernetes no EKS -- 1.31 porque é a que o cluster real está rodando hoje (EKS não suporta downgrade; o default aqui precisa sempre bater com a versão ao vivo, não com o que foi pedido na criação)."
  type        = string
  default     = "1.31"
}

variable "node_instance_type" {
  description = "Tipo de instância do managed node group"
  type        = string
  default     = "t3.small"
}

variable "node_min_size" {
  type    = number
  default = 2
}

variable "node_max_size" {
  type    = number
  default = 4
}

variable "ecr_repository_name" {
  description = "Nome do repositório ECR da imagem da API"
  type        = string
  default     = "soat15-tc-oficina-api"
}

variable "enable_new_relic" {
  description = "Liga o nri-bundle (agente de infraestrutura do New Relic) no cluster. Fica false até existir uma license key válida (TF_VAR_new_relic_license_key) -- sem ela, o pod entra em CrashLoopBackOff."
  type        = bool
  default     = false
}

variable "new_relic_license_key" {
  description = "License key de ingestão do New Relic (conta free tier) -- passe via TF_VAR_new_relic_license_key, nunca em texto no repositório."
  type        = string
  default     = ""
  sensitive   = true
}

variable "enable_new_relic_dashboards" {
  description = "Liga os 4 dashboards e os alertas NRQL (newrelic_dashboards.tf/newrelic_alerts.tf), provisionados via provider newrelic/newrelic. Credencial separada da license key (essa é um User API Key) -- fica false até existir uma."
  type        = bool
  default     = false
}

variable "new_relic_api_key" {
  description = "User API Key do New Relic (Personal API key, tipo NRAK -- não é a license key de ingestão) usada pelo provider newrelic/newrelic para criar dashboards e alertas. Passe via TF_VAR_new_relic_api_key."
  type        = string
  default     = ""
  sensitive   = true
}

variable "new_relic_account_id" {
  description = "Account ID numérico da conta New Relic (visível na URL da UI ou em API keys > Account ID). Passe via TF_VAR_new_relic_account_id."
  type        = number
  default     = 0
}

variable "alert_notification_email" {
  description = "E-mail que recebe os alertas NRQL (cria destination/channel/workflow no New Relic). Vazio = alertas ficam registrados na conta sem notificação ativa."
  type        = string
  default     = ""
}
