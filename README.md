# soat15-tech-challenge-k8s-infra

Terraform do cluster Kubernetes gerenciado (Amazon EKS) da Fase 3 do Tech Challenge
(SOAT), mais o registro de imagem (ECR) e a aplicação dos manifestos de
[`k8s/`](https://github.com/PedrosPinho/soat15-tech-challenge-01/tree/main/k8s) do
repositório da aplicação.

## Escopo deste repositório

- `aws_eks_cluster` + managed node group (`t3.small`, min 2 / max 4) nas subnets
  privadas da VPC exportada por
  [`db-infra`](https://github.com/PedrosPinho/soat15-tech-challenge-db-infra)
- Addons: `vpc-cni`, `coredns`, `kube-proxy`, `metrics-server` (pré-requisito do HPA)
- AWS Load Balancer Controller via Helm
- `aws_ecr_repository` para a imagem da API
- **Sem IRSA** — cluster role e node role são a `LabRole` compartilhada, concessão
  deliberada documentada em
  [`ADR-006`](https://github.com/PedrosPinho/soat15-tech-challenge-01/blob/main/docs/architecture/adrs/ADR-006-labrole-compartilhada-sem-irsa.md)
  no repositório da aplicação

## Dependências

Depende de [`db-infra`](https://github.com/PedrosPinho/soat15-tech-challenge-db-infra)
(VPC/subnets/security groups, via `terraform_remote_state` em `remote_state.tf`) —
aplicar **depois** dele.

## Estado remoto

Mesmo bucket S3/tabela DynamoDB de `db-infra`, `key` própria (`k8s-infra/terraform.tfstate`)
— ver `backend.tf`.

## Uso

```bash
terraform init
terraform plan -out=tfplan
terraform apply tfplan

# smoke test pós-apply
aws eks update-kubeconfig --name soat15-tc-cluster --region us-east-1
kubectl get nodes
kubectl get hpa -n oficina
```

## Ciclo de sessão do Learner Lab

EKS é o maior consumidor do orçamento do lab (~US$ 0,10/h só o control plane).
`terraform apply` no início de cada sessão, `terraform destroy` ao final — ver
[`PHASE_3_EXECUTION_GUIDE.md`](https://github.com/PedrosPinho/soat15-tech-challenge-01/blob/main/docs/PHASE_3_EXECUTION_GUIDE.md)
no repositório da aplicação para a ordem completa entre os 4 repositórios.
