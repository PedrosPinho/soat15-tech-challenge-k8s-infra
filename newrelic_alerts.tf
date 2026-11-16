# Os 6 alertas exigidos pela Etapa 5 do PHASE_3_PLAN.md, como código via
# provider newrelic/newrelic -- mesmo gate de newrelic_dashboards.tf
# (var.enable_new_relic_dashboards).
#
# Uma política única agrupa as 6 condições (aggregation_method "cadence"
# padrão do provider já resolve o reabrir/fechar do incidente). Notificação
# por e-mail é opcional (var.alert_notification_email) -- sem ela, os alertas
# ficam registrados e visíveis na conta, só sem disparar nada externamente.

resource "newrelic_alert_policy" "oficina" {
  count = var.enable_new_relic_dashboards ? 1 : 0

  name                = "Oficina — Fase 3"
  incident_preference = "PER_CONDITION"
}

resource "newrelic_nrql_alert_condition" "erro_5xx" {
  count = var.enable_new_relic_dashboards ? 1 : 0

  policy_id                    = newrelic_alert_policy.oficina[0].id
  type                         = "static"
  name                         = "Taxa de erro 5xx acima do limite"
  enabled                      = true
  violation_time_limit_seconds = 3600

  nrql {
    query = "SELECT percentage(count(*), WHERE httpResponseCode LIKE '5%') FROM Transaction WHERE ${local.apm_app_filter}"
  }

  critical {
    operator              = "above"
    threshold             = 5
    threshold_duration    = 300
    threshold_occurrences = "at_least_once"
  }

  fill_option = "none"
}

resource "newrelic_nrql_alert_condition" "p95_degradado" {
  count = var.enable_new_relic_dashboards ? 1 : 0

  policy_id                    = newrelic_alert_policy.oficina[0].id
  type                         = "static"
  name                         = "p95 de latência degradado"
  enabled                      = true
  violation_time_limit_seconds = 3600

  nrql {
    query = "SELECT percentile(duration, 95) FROM Transaction WHERE ${local.apm_app_filter}"
  }

  critical {
    operator              = "above"
    threshold             = 1.5
    threshold_duration    = 300
    threshold_occurrences = "at_least_once"
  }

  fill_option = "none"
}

resource "newrelic_nrql_alert_condition" "falha_processamento_os" {
  count = var.enable_new_relic_dashboards ? 1 : 0

  policy_id                    = newrelic_alert_policy.oficina[0].id
  type                         = "static"
  name                         = "Falha no processamento de ordens de serviço"
  enabled                      = true
  violation_time_limit_seconds = 3600

  # Cobre exceções em qualquer use-case de transição de status (todos
  # expostos sob /api/ordens-servico -- ver ordens-servico.routes.ts).
  nrql {
    query = "SELECT count(*) FROM TransactionError WHERE ${local.apm_app_filter} AND transactionName LIKE '%ordens-servico%'"
  }

  critical {
    operator              = "above"
    threshold             = 0
    threshold_duration    = 300
    threshold_occurrences = "at_least_once"
  }

  fill_option = "none"
}

resource "newrelic_nrql_alert_condition" "crashloopbackoff" {
  count = var.enable_new_relic_dashboards ? 1 : 0

  policy_id                    = newrelic_alert_policy.oficina[0].id
  type                         = "static"
  name                         = "Pod em CrashLoopBackOff"
  enabled                      = true
  violation_time_limit_seconds = 3600

  nrql {
    query = "SELECT uniqueCount(podName) FROM K8sContainerSample WHERE clusterName = '${local.k8s_cluster_name}' AND status = 'Waiting' AND reason = 'CrashLoopBackOff' FACET podName"
  }

  critical {
    operator              = "above"
    threshold             = 0
    threshold_duration    = 300
    threshold_occurrences = "at_least_once"
  }

  fill_option = "none"
}

resource "newrelic_nrql_alert_condition" "cpu_sustentada" {
  count = var.enable_new_relic_dashboards ? 1 : 0

  policy_id                    = newrelic_alert_policy.oficina[0].id
  type                         = "static"
  name                         = "CPU sustentada acima do alvo do HPA"
  enabled                      = true
  violation_time_limit_seconds = 3600

  # Alvo do HPA em k8s/hpa.yaml (repositório da aplicação) é 70% de CPU
  # requisitada -- alerta em 80% sustentado por 10min para não duplicar o
  # próprio scale-out do HPA, só sinalizar quando ele não dá conta.
  nrql {
    query = "SELECT average(cpuUsedCores) * 100 FROM K8sContainerSample WHERE clusterName = '${local.k8s_cluster_name}' AND podName LIKE 'oficina-api%'"
  }

  critical {
    operator              = "above"
    threshold             = 80
    threshold_duration    = 600
    threshold_occurrences = "all"
  }

  fill_option = "none"
}

# Healthcheck/uptime via Synthetics -- monitor público batendo em /health/ready
# através do API Gateway (rota adicionada em auth-lambda/terraform/api_gateway.tf,
# sem autorizador, fora do prefixo /api/ que o catch-all cobre).
#
# count também depende do output de auth-lambda já existir: numa reconstrução do
# zero, k8s-infra é aplicado antes de auth-lambda (ver README), então o remote
# state ainda não tem esse output na primeira passada -- sem o try() aqui, o
# apply inteiro falha no plan (não só este recurso). Reaplicar depois que
# auth-lambda existir liga o monitor normalmente.
resource "newrelic_synthetics_monitor" "healthcheck" {
  count = var.enable_new_relic_dashboards && try(data.terraform_remote_state.auth_lambda.outputs.api_gateway_endpoint, "") != "" ? 1 : 0

  status           = "ENABLED"
  name             = "Oficina — healthcheck /health/ready"
  period           = "EVERY_5_MINUTES"
  uri              = "${try(data.terraform_remote_state.auth_lambda.outputs.api_gateway_endpoint, "")}/health/ready"
  type             = "SIMPLE"
  locations_public = ["AWS_US_EAST_1"]
  verify_ssl       = true
}

resource "newrelic_nrql_alert_condition" "healthcheck_falhando" {
  # Mesma condição do monitor acima -- sem ele criado (auth-lambda ainda não
  # existe), não há o que indexar em newrelic_synthetics_monitor.healthcheck[0].
  count = length(newrelic_synthetics_monitor.healthcheck) > 0 ? 1 : 0

  policy_id                    = newrelic_alert_policy.oficina[0].id
  type                         = "static"
  name                         = "Healthcheck /health/ready falhando"
  enabled                      = true
  violation_time_limit_seconds = 3600

  nrql {
    query = "SELECT count(*) FROM SyntheticCheck WHERE monitorName = '${newrelic_synthetics_monitor.healthcheck[0].name}' AND result = 'FAILED'"
  }

  critical {
    operator              = "above"
    threshold             = 0
    threshold_duration    = 300
    threshold_occurrences = "at_least_once"
  }

  fill_option = "none"
}

# Notificação por e-mail -- opcional, só existe com var.alert_notification_email
# preenchido (TF_VAR_alert_notification_email no pipeline).
resource "newrelic_notification_destination" "email" {
  count = var.enable_new_relic_dashboards && var.alert_notification_email != "" ? 1 : 0

  name = "oficina-email"
  type = "EMAIL"

  property {
    key   = "email"
    value = var.alert_notification_email
  }
}

resource "newrelic_notification_channel" "email" {
  count = var.enable_new_relic_dashboards && var.alert_notification_email != "" ? 1 : 0

  name           = "oficina-email"
  type           = "EMAIL"
  destination_id = newrelic_notification_destination.email[0].id
  product        = "IINT"

  property {
    key   = "subject"
    value = "{{issueTitle}}"
  }
}

resource "newrelic_workflow" "oficina" {
  count = var.enable_new_relic_dashboards && var.alert_notification_email != "" ? 1 : 0

  name                  = "oficina-alertas"
  muting_rules_handling = "NOTIFY_ALL_ISSUES"

  issues_filter {
    name = "oficina-policy-filter"
    type = "FILTER"

    predicate {
      attribute = "labels.policyIds"
      operator  = "EXACTLY_MATCHES"
      values    = [newrelic_alert_policy.oficina[0].id]
    }
  }

  destination {
    channel_id = newrelic_notification_channel.email[0].id
  }
}
