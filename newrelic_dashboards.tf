# Os 4 dashboards exigidos pela Etapa 5 do PHASE_3_PLAN.md (repositório da
# aplicação), como código via provider newrelic/newrelic -- gated por
# var.enable_new_relic_dashboards (precisa de var.new_relic_api_key + var.new_relic_account_id,
# credenciais separadas da license key usada só para ingestão).
#
# As duas primeiras leem o evento customizado `OrdemServicoStatusChanged`,
# emitido em src/application/use-cases/ordem-servico/notificar-mudanca-status.helper.ts
# (ver repositório da aplicação) por todos os 7 use-cases de transição de
# status. As duas últimas leem dados padrão do agente APM (Transaction/TransactionError)
# e do nri-bundle (K8sContainerSample, K8sPodSample).
#
# Nomes de atributo do K8sContainerSample (cpuUsedCores/memoryUsedBytes) e o
# nome do cluster seguem a convenção padrão do nri-kubernetes -- confirmar
# contra dados reais na conta assim que o nri-bundle estiver reportando (mesma
# ressalva de "conferir antes de fixar" já usada para as versões de Helm chart
# em newrelic.tf/addons.tf/lb_controller.tf).

locals {
  # Nome da app no agente vem de NEW_RELIC_APP_NAME = "oficina-api-${TF_ENV}"
  # (ver .github/workflows/ci-cd.yml no repositório da aplicação) -- o LIKE
  # cobre tanto oficina-api-homolog quanto oficina-api-prod.
  apm_app_filter = "appName LIKE 'oficina-api-%'"

  # Precisa bater com global.cluster em newrelic.tf (o nome que o nri-bundle
  # reporta como clusterName em K8sContainerSample/K8sPodSample) -- k8s-infra
  # não usa workspaces (ver terraform.yml), então terraform.workspace é sempre
  # "default" aqui.
  k8s_cluster_name = "${var.project_name}-${terraform.workspace}"
}

resource "newrelic_one_dashboard" "os_volume_diario" {
  count = var.enable_new_relic_dashboards ? 1 : 0

  name        = "Oficina — Volume diário de OS"
  permissions = "public_read_only"

  page {
    name = "Volume"

    widget_billboard {
      title  = "OS recebidas (últimas 24h)"
      row    = 1
      column = 1
      width  = 4
      height = 3

      nrql_query {
        account_id = var.new_relic_account_id
        query      = "SELECT count(*) FROM OrdemServicoStatusChanged WHERE statusNovo = 'RECEBIDA' SINCE 1 day ago"
      }
    }

    widget_line {
      title  = "OS abertas por dia"
      row    = 1
      column = 5
      width  = 8
      height = 3

      nrql_query {
        account_id = var.new_relic_account_id
        query      = "SELECT count(*) FROM OrdemServicoStatusChanged WHERE statusNovo = 'RECEBIDA' TIMESERIES 1 day SINCE 30 days ago"
      }
    }
  }
}

resource "newrelic_one_dashboard" "tempo_medio_por_status" {
  count = var.enable_new_relic_dashboards ? 1 : 0

  name        = "Oficina — Tempo médio por status"
  permissions = "public_read_only"

  page {
    name = "Tempo por status"

    # funnel() calcula o tempo médio/mediano entre passos para o mesmo
    # facet (numeroOS) -- é o jeito nativo do NRQL de medir "quanto tempo uma
    # OS levou entre entrar em Diagnóstico e entrar em Execução" sem precisar
    # guardar uma duração explícita no evento.
    widget_funnel {
      title  = "Diagnóstico → Execução → Finalização"
      row    = 1
      column = 1
      width  = 12
      height = 4

      nrql_query {
        account_id = var.new_relic_account_id
        query      = <<-NRQL
          SELECT funnel(timestamp,
            WHERE statusNovo = 'RECEBIDA' AS 'Recebida',
            WHERE statusNovo = 'EM_DIAGNOSTICO' AS 'Diagnóstico',
            WHERE statusNovo = 'EM_EXECUCAO' AS 'Execução',
            WHERE statusNovo = 'FINALIZADA' AS 'Finalização')
          FROM OrdemServicoStatusChanged
          FACET numeroOS
          SINCE 30 days ago
        NRQL
      }
    }

    widget_bar {
      title  = "Transições por status (7 dias)"
      row    = 5
      column = 1
      width  = 12
      height = 3

      nrql_query {
        account_id = var.new_relic_account_id
        query      = "SELECT count(*) FROM OrdemServicoStatusChanged FACET statusNovo SINCE 7 days ago"
      }
    }
  }
}

resource "newrelic_one_dashboard" "erros_integracoes" {
  count = var.enable_new_relic_dashboards ? 1 : 0

  name        = "Oficina — Erros e falhas nas integrações"
  permissions = "public_read_only"

  page {
    name = "Integrações"

    widget_line {
      title  = "Erros da API (RDS/lógica de negócio) por rota"
      row    = 1
      column = 1
      width  = 12
      height = 3

      nrql_query {
        account_id = var.new_relic_account_id
        query      = "SELECT count(*) FROM TransactionError WHERE ${local.apm_app_filter} FACET transactionName TIMESERIES AUTO SINCE 7 days ago"
      }
    }

    widget_line {
      title  = "Falhas ao notificar cliente (SES) por dia"
      row    = 4
      column = 1
      width  = 6
      height = 3

      nrql_query {
        account_id = var.new_relic_account_id
        query      = "SELECT count(*) FROM Log WHERE message LIKE '%Falha ao notificar cliente%' TIMESERIES 1 day SINCE 30 days ago"
      }
    }

    # Lambda de auth não é instrumentada pelo agente New Relic (sem NAT
    # Gateway para egress e Learner Lab bloqueia a IAM role custom exigida
    # pela integração CloudWatch -- ver docs/PHASE_3_TASKS.md, Etapa 5,
    # "Pendências"). Este painel documenta a lacuna em vez de escondê-la.
    widget_markdown {
      title  = "Lambda de auth"
      row    = 4
      column = 7
      width  = 6
      height = 3

      text = <<-MD
        **Sem instrumentação New Relic.** As Lambdas de auth rodam em subnets
        privadas sem NAT Gateway (sem egress à internet) e o Learner Lab
        bloqueia a criação de IAM role custom exigida pela integração via
        CloudWatch Metric Streams. Monitorar erros dessas Lambdas por
        `aws logs tail /aws/lambda/soat15-tc-*-token --follow` ou
        `aws cloudwatch get-metric-statistics --metric-name Errors` até
        essa limitação do Learner Lab deixar de existir.
      MD
    }
  }
}

resource "newrelic_one_dashboard" "latencia_e_recursos" {
  count = var.enable_new_relic_dashboards ? 1 : 0

  name        = "Oficina — Latência e recursos do cluster"
  permissions = "public_read_only"

  page {
    name = "Latência e recursos"

    widget_line {
      title  = "Latência p50/p95/p99 por rota"
      row    = 1
      column = 1
      width  = 12
      height = 4

      nrql_query {
        account_id = var.new_relic_account_id
        query      = "SELECT percentile(duration, 50, 95, 99) FROM Transaction WHERE ${local.apm_app_filter} TIMESERIES AUTO SINCE 3 days ago"
      }
    }

    widget_line {
      title  = "CPU por pod (cores)"
      row    = 5
      column = 1
      width  = 6
      height = 3

      nrql_query {
        account_id = var.new_relic_account_id
        query      = "SELECT average(cpuUsedCores) FROM K8sContainerSample WHERE clusterName = '${local.k8s_cluster_name}' FACET podName TIMESERIES AUTO SINCE 3 days ago"
      }
    }

    widget_line {
      title  = "Memória por pod (MB)"
      row    = 5
      column = 7
      width  = 6
      height = 3

      nrql_query {
        account_id = var.new_relic_account_id
        query      = "SELECT average(memoryUsedBytes) / 1e6 AS 'MB' FROM K8sContainerSample WHERE clusterName = '${local.k8s_cluster_name}' FACET podName TIMESERIES AUTO SINCE 3 days ago"
      }
    }
  }
}
