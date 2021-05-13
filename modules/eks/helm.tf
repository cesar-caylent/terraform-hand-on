# --------------------------------------------------------------------
# Helm charts
# --------------------------------------------------------------------
# NOTE: Usage of try in for_each due to this open issue
# https://github.com/hashicorp/terraform/issues/22405

resource "helm_release" "chart" {
  for_each         = try(var.deploy_charts ? var.charts : tomap(false), {})
  name             = each.key
  repository       = each.value.repository
  chart            = each.value.chart
  version          = each.value.version
  namespace        = each.value.namespace
  create_namespace = each.value.create_namespace
  values           = lookup(var.charts[each.key], "values", []) != [] ? [for v in each.value.values : try(file(v), "")] : []
  timeout          = var.release_timeout
  wait             = var.release_wait
  lint             = var.release_lint

  dynamic "set_sensitive" {
    for_each = lookup(var.charts[each.key], "set_sensitive", {})
    content {
      name  = set_sensitive.value.name
      value = set_sensitive.value.value
      type  = set_sensitive.value.type
    }
  }

  dynamic "set" {
    for_each = lookup(var.charts[each.key], "set", {})
    content {
      name  = set.value.name
      value = set.value.value
      type  = set.value.type
    }
  }
}
