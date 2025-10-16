resource "helm_release" "obico" {
  name       = "obico"
  namespace  = kubernetes_namespace.apps.metadata[0].name
  chart      = "obico"
  repository = "https://charts.gabe565.com"
  version    = "0.6.0"
  values     = [file("${path.module}/values/obico-values.yaml")]
  depends_on = [kubernetes_namespace.apps]
  timeout    = 600

  lifecycle {
    ignore_changes = [metadata]
  }

  set = [{
    name  = "EMAIL_HOST_PASSWORD"
    value = var.gmail_app_pass
  }]
}
