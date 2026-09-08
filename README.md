# soat15-tech-challenge-k8s-infra

Terraform do cluster Kubernetes gerenciado (Amazon EKS) da Fase 3 do Tech Challenge
(SOAT), mais o registro de imagem (ECR) e a aplicação dos manifestos de
[`k8s/`](https://github.com/PedrosPinho/soat15-tech-challenge-01/tree/main/k8s) do
repositório da aplicação.

## Escopo deste repositório

- `aws_eks_cluster` + managed node group (`t3.small`, min 2 / max 4) nas subnets
  **públicas** da VPC exportada por
  [`db-infra`](https://github.com/PedrosPinho/soat15-tech-challenge-db-infra) —
  diverge do texto original de `PHASE_3_PLAN.md` ("subnets privadas"): como a VPC não
  tem NAT Gateway (decisão de `db-infra`, orçamento do Learner Lab), nós em subnet
  privada não alcançariam ECR/API do EKS. O security group customizado
  `eks_nodes_security_group_id` (exportado por `db-infra`) é anexado às instâncias via
  launch template para manter o tráfego restrito, já que o isolamento não vem mais da
  subnet.
- Addons: `vpc-cni`, `coredns`, `kube-proxy` via `aws_eks_addon`; `metrics-server`
  (pré-requisito do HPA) via `helm_release` — ver decisão em `addons.tf`.
- AWS Load Balancer Controller via Helm, sem annotation de IRSA no ServiceAccount
  (herda a `LabRole` pelo instance profile do nó). Subnets tagueadas
  (`aws_ec2_tag`) para a auto-descoberta que o controller precisa.
- `aws_ecr_repository` para a imagem da API, com lifecycle policy mantendo as
  últimas ~10 imagens.
- `nri-bundle` (agente de infraestrutura do New Relic) via Helm — gated por
  `var.enable_new_relic` (default `false`; sem license key válida o pod entra
  em `CrashLoopBackOff`). O pipeline liga a flag sozinho quando o GitHub
  Secret `NEW_RELIC_LICENSE_KEY` existir — ver `newrelic.tf` e a seção
  [CI/CD](#cicd).
- **Sem IRSA** — cluster role e node role são a `LabRole` compartilhada, concessão
  deliberada documentada em
  [`ADR-006`](https://github.com/PedrosPinho/soat15-tech-challenge-01/blob/main/docs/architecture/adrs/ADR-006-labrole-compartilhada-sem-irsa.md)
  no repositório da aplicação
- **Fora de escopo por ora**: aplicar os manifestos de `k8s/` do repositório da
  aplicação (deployment, service, hpa, configmap, secret, namespace) dentro deste
  Terraform. Fica como acompanhamento futuro — candidato natural a um `helm_release`
  apontando para um chart local ou a `kubectl_manifest` (provider `gavinbunney/kubectl`
  ou `hashicorp/kubernetes` via `kubernetes_manifest`), aplicado depois que a imagem
  já existir no ECR.

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
kubectl get hpa -n oficina-homolog   # ou oficina-prod
```

## CI/CD

Pipeline em `.github/workflows/terraform.yml`: `fmt` → `validate` → `tflint` →
`plan` (em PR, comentado no PR) → `apply` (push em `homolog`/`main`) + smoke
test `kubectl get nodes`/`wait --for=condition=Ready`. Homolog e prod
**compartilham o mesmo cluster** (sem workspaces aqui — a separação é por
namespace no lado da aplicação), então o `apply` de qualquer uma das duas
branches atualiza a mesma infraestrutura.

**Secrets do GitHub**: `AWS_ACCESS_KEY_ID`/`AWS_SECRET_ACCESS_KEY`/
`AWS_SESSION_TOKEN` (credenciais temporárias do Learner Lab, renovadas por
`scripts/refresh-aws-secrets.sh` no repositório da aplicação) e,
opcionalmente, `NEW_RELIC_LICENSE_KEY` (liga o `nri-bundle`, ver acima).

**Atenção a `var.cluster_version`**: precisa sempre bater com a versão que o
cluster está rodando *de verdade* (não a que foi pedida na criação) — EKS não
suporta downgrade, e um diff pendente nesse atributo quebra o `apply` inteiro
(os providers `kubernetes`/`helm` deste repositório, configurados a partir de
atributos do `aws_eks_cluster`, param de conseguir autenticar enquanto o
recurso tem qualquer mudança pendente). Se o `apply` começar a falhar com
`system:anonymous cannot list resource "secrets"`, confira primeiro se a AWS
não fez um upgrade de versão fora deste Terraform.

## Ciclo de sessão do Learner Lab

EKS é o maior consumidor do orçamento do lab (~US$ 0,10/h só o control plane).
`terraform apply` no início de cada sessão, `terraform destroy` ao final — ver
[`PHASE_3_EXECUTION_GUIDE.md`](https://github.com/PedrosPinho/soat15-tech-challenge-01/blob/main/docs/PHASE_3_EXECUTION_GUIDE.md)
no repositório da aplicação para a ordem completa entre os 4 repositórios.
