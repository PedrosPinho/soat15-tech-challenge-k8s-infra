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
  description = "Versão do Kubernetes no EKS"
  type        = string
  default     = "1.30"
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
