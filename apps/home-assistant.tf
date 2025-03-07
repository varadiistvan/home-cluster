resource "helm_release" "home_assistant" {
  name       = "home-assistant"
  namespace  = kubernetes_namespace.apps.metadata[0].name
  chart      = "home-assistant"
  version    = "0.2.102"
  repository = "http://pajikos.github.io/home-assistant-helm-chart/"
  values     = [file("${path.module}/values/home-assistant-values.yaml")]
  depends_on = [kubernetes_namespace.apps]
}
