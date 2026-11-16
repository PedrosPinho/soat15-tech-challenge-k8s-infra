# Fase 4 (Etapa 7, T7.6): observabilidade da Saga e dos 3 microsserviços — dashboard "Saga /
# Microsserviços" e 4 alertas, no mesmo gate dos demais (var.enable_new_relic_dashboards) e na
# mesma política de alertas (newrelic_alert_policy.oficina).
#
# Eventos customizados emitidos pelos serviços (nomes/atributos em src/shared/observability/ e
# application/saga/saga-orchestrator.ts do repo soat15-tech-challenge-01):
#   SagaIniciada{ordemServicoId, numeroOS}                              OS, ao abrir a OS
#   SagaPassoExecutado{sagaId, ordemServicoId, passo, acao, resultado}  OS, a cada passo/compensação
#   SagaFinalizada{sagaId, ordemServicoId, resultado, duracaoMs}        OS, ao entrar em estado terminal
#                                                                       (resultado: CONCLUIDA | COMPENSADA | FALHA_COMPENSACAO)
#   FilaProfundidade{servico, fila, tipo, mensagens, emVoo, atrasadas}  os 3 serviços, a cada 60 s
#                                                                       (tipo: principal | dlq)
# Como na Fase 3, nomes de atributo/evento devem ser conferidos contra dados reais assim que os
# serviços estiverem reportando.

locals {
  # appName vem de NEW_RELIC_APP_NAME = "<serviço>-<env>" (ver ci-cd.yml de cada serviço).
  servicos_app_filter = "(appName LIKE 'oficina-api-%' OR appName LIKE 'billing-service-%' OR appName LIKE 'execution-service-%')"
  billing_app_filter  = "appName LIKE 'billing-service-%'"
}

resource "newrelic_one_dashboard" "saga_microsservicos" {
  count = var.enable_new_relic_dashboards ? 1 : 0

  name        = "Oficina — Saga / Microsserviços"
  permissions = "public_read_only"

  page {
    name = "Saga"

    widget_billboard {
      title  = "Sagas iniciadas (24h)"
      row    = 1
      column = 1
      width  = 3
      height = 3

      nrql_query {
        account_id = var.new_relic_account_id
        query      = "SELECT count(*) FROM SagaIniciada SINCE 1 day ago"
      }
    }

    widget_billboard {
      title  = "Taxa de compensação (24h, %)"
      row    = 1
      column = 4
      width  = 3
      height = 3

      nrql_query {
        account_id = var.new_relic_account_id
        query      = "SELECT percentage(count(*), WHERE resultado != 'CONCLUIDA') FROM SagaFinalizada SINCE 1 day ago"
      }
    }

    widget_billboard {
      title  = "Sagas em FALHA_COMPENSACAO (7d)"
      row    = 1
      column = 7
      width  = 3
      height = 3

      nrql_query {
        account_id = var.new_relic_account_id
        query      = "SELECT count(*) FROM SagaFinalizada WHERE resultado = 'FALHA_COMPENSACAO' SINCE 7 days ago"
      }
    }

    widget_billboard {
      title  = "Mensagens em DLQ agora"
      row    = 1
      column = 10
      width  = 3
      height = 3

      nrql_query {
        account_id = var.new_relic_account_id
        query      = "SELECT sum(mensagens) FROM (SELECT latest(mensagens) AS mensagens FROM FilaProfundidade WHERE tipo = 'dlq' FACET fila) SINCE 10 minutes ago"
      }
    }

    widget_line {
      title  = "Sagas iniciadas × finalizadas por hora"
      row    = 4
      column = 1
      width  = 6
      height = 3

      nrql_query {
        account_id = var.new_relic_account_id
        query      = "SELECT count(*) AS iniciadas FROM SagaIniciada TIMESERIES 1 hour SINCE 3 days ago"
      }

      nrql_query {
        account_id = var.new_relic_account_id
        query      = "SELECT count(*) FROM SagaFinalizada FACET resultado TIMESERIES 1 hour SINCE 3 days ago"
      }
    }

    widget_bar {
      title  = "Duração média da saga (s) por resultado"
      row    = 4
      column = 7
      width  = 6
      height = 3

      nrql_query {
        account_id = var.new_relic_account_id
        query      = "SELECT average(duracaoMs) / 1000 FROM SagaFinalizada FACET resultado SINCE 1 day ago"
      }
    }

    widget_bar {
      title  = "Passos executados por passo e resultado"
      row    = 7
      column = 1
      width  = 6
      height = 3

      nrql_query {
        account_id = var.new_relic_account_id
        query      = "SELECT count(*) FROM SagaPassoExecutado FACET passo, resultado SINCE 1 day ago"
      }
    }

    widget_table {
      title  = "Últimas sagas finalizadas"
      row    = 7
      column = 7
      width  = 6
      height = 3

      nrql_query {
        account_id = var.new_relic_account_id
        query      = "SELECT ordemServicoId, resultado, duracaoMs FROM SagaFinalizada SINCE 1 day ago LIMIT 20"
      }
    }
  }

  page {
    name = "Filas e serviços"

    widget_line {
      title  = "Profundidade das filas (mensagens visíveis)"
      row    = 1
      column = 1
      width  = 6
      height = 3

      nrql_query {
        account_id = var.new_relic_account_id
        query      = "SELECT max(mensagens) FROM FilaProfundidade WHERE tipo = 'principal' FACET fila TIMESERIES AUTO SINCE 3 hours ago"
      }
    }

    widget_line {
      title  = "Profundidade das DLQs"
      row    = 1
      column = 7
      width  = 6
      height = 3

      nrql_query {
        account_id = var.new_relic_account_id
        query      = "SELECT max(mensagens) FROM FilaProfundidade WHERE tipo = 'dlq' FACET fila TIMESERIES AUTO SINCE 3 hours ago"
      }
    }

    widget_line {
      title  = "Throughput por serviço (req/min)"
      row    = 4
      column = 1
      width  = 6
      height = 3

      nrql_query {
        account_id = var.new_relic_account_id
        query      = "SELECT rate(count(*), 1 minute) FROM Transaction WHERE ${local.servicos_app_filter} FACET appName TIMESERIES AUTO SINCE 3 hours ago"
      }
    }

    widget_line {
      title  = "Erros por serviço"
      row    = 4
      column = 7
      width  = 6
      height = 3

      nrql_query {
        account_id = var.new_relic_account_id
        query      = "SELECT count(*) FROM TransactionError WHERE ${local.servicos_app_filter} FACET appName TIMESERIES AUTO SINCE 3 hours ago"
      }
    }

    widget_markdown {
      title  = "Service map e traces distribuídos"
      row    = 7
      column = 1
      width  = 12
      height = 2

      text = <<-MD
        **Service map**: APM → *Service map* (ou *Services - APM → Map*), filtrando por `oficina-api`, `billing-service` e `execution-service`.
        **Trace de uma OS**: *Distributed tracing* → busque por `ordemServicoId` (atributo da transação) — o trace atravessa OS → Billing/Execution → OS pelas filas SQS/SNS.
        **Logs de uma OS**: *Logs* → `sagaId:"..."` ou `ordemServicoId:"..."`.
      MD
    }
  }
}

# --- Alertas (mesma política "Oficina — Fase 3") -------------------------------------------------

resource "newrelic_nrql_alert_condition" "saga_falha_compensacao" {
  count = var.enable_new_relic_dashboards ? 1 : 0

  policy_id                    = newrelic_alert_policy.oficina[0].id
  type                         = "static"
  name                         = "Saga em FALHA_COMPENSACAO (intervenção manual)"
  enabled                      = true
  violation_time_limit_seconds = 86400

  nrql {
    query = "SELECT count(*) FROM SagaFinalizada WHERE resultado = 'FALHA_COMPENSACAO'"
  }

  critical {
    operator              = "above"
    threshold             = 0
    threshold_duration    = 300
    threshold_occurrences = "at_least_once"
  }

  fill_option = "none"
}

resource "newrelic_nrql_alert_condition" "mensagem_em_dlq" {
  count = var.enable_new_relic_dashboards ? 1 : 0

  policy_id                    = newrelic_alert_policy.oficina[0].id
  type                         = "static"
  name                         = "Mensagem em DLQ"
  enabled                      = true
  violation_time_limit_seconds = 86400

  # Uma DLQ com mensagem = comando/evento que falhou 5 vezes (maxReceiveCount) ou era inválido.
  nrql {
    query = "SELECT max(mensagens) FROM FilaProfundidade WHERE tipo = 'dlq'"
  }

  critical {
    operator              = "above"
    threshold             = 0
    threshold_duration    = 300
    threshold_occurrences = "at_least_once"
  }

  fill_option = "none"
}

resource "newrelic_nrql_alert_condition" "taxa_compensacao_alta" {
  count = var.enable_new_relic_dashboards ? 1 : 0

  policy_id                    = newrelic_alert_policy.oficina[0].id
  type                         = "static"
  name                         = "Taxa de compensação das sagas acima de 50%"
  enabled                      = true
  violation_time_limit_seconds = 3600

  nrql {
    query = "SELECT percentage(count(*), WHERE resultado = 'COMPENSADA') FROM SagaFinalizada"
  }

  critical {
    operator              = "above"
    threshold             = 50
    threshold_duration    = 900
    threshold_occurrences = "all"
  }

  fill_option = "none"
}

resource "newrelic_nrql_alert_condition" "webhook_mercadopago_erro" {
  count = var.enable_new_relic_dashboards ? 1 : 0

  policy_id                    = newrelic_alert_policy.oficina[0].id
  type                         = "static"
  name                         = "Erro no webhook do Mercado Pago"
  enabled                      = true
  violation_time_limit_seconds = 3600

  # 401 (assinatura inválida) não é TransactionError; 5xx ao consultar/gravar o pagamento é.
  nrql {
    query = "SELECT count(*) FROM TransactionError WHERE ${local.billing_app_filter} AND transactionName LIKE '%webhooks/mercadopago%'"
  }

  critical {
    operator              = "above"
    threshold             = 0
    threshold_duration    = 300
    threshold_occurrences = "at_least_once"
  }

  fill_option = "none"
}
