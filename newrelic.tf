# nri-bundle: agente de infraestrutura do New Relic no cluster (CPU/memória de
# pods e nós, eventos e estado do cluster, kube-state-metrics, forwarder de
# logs do stdout JSON dos pods) -- ver Etapa 5 do PHASE_3_PLAN.md e
# docs/architecture/rfcs/RFC-004-observabilidade.md (repositório da aplicação).
#
# Gated por var.enable_new_relic (default false), mesmo padrão de "só liga
# quando a credencial existir" já usado em enable_vpc_link_integration
# (repositório auth-lambda): sem uma license key válida, o pod do
# newrelic-infrastructure entra em CrashLoopBackOff, o que quebraria o estado
# do cluster para todo o resto. O pipeline liga a flag sozinho quando o
# GitHub Secret NEW_RELIC_LICENSE_KEY existir (ver ci-cd.yml).
#
# Sem `version` fixada pelo mesmo motivo do metrics-server/LB controller
# (addons.tf/lb_controller.tf): confirmar com `helm search repo newrelic/nri-bundle
# --versions` antes do primeiro apply de verdade e fixar aqui.
resource "helm_release" "nri_bundle" {
  count = var.enable_new_relic ? 1 : 0

  name             = "nri-bundle"
  repository       = "https://helm-charts.newrelic.com"
  chart            = "nri-bundle"
  namespace        = "newrelic"
  create_namespace = true

  set {
    name  = "global.cluster"
    value = "${var.project_name}-${terraform.workspace}"
  }

  set_sensitive {
    name  = "global.licenseKey"
    value = var.new_relic_license_key
  }

  set {
    name  = "global.lowDataMode"
    value = "true"
  }

  set {
    name  = "newrelic-infrastructure.privileged"
    value = "true"
  }

  set {
    name  = "kube-state-metrics.enabled"
    value = "true"
  }

  set {
    name  = "kubeEvents.enabled"
    value = "true"
  }

  set {
    name  = "logging.enabled"
    value = "true"
  }

  depends_on = [aws_eks_node_group.this]
}
