resource "helm_release" "siyuan" {
  name       = "siyuan"
  namespace  = kubernetes_namespace.apps.metadata[0].name
  chart      = "siyuan"
  repository = "https://ex-trim.github.io/helm-charts"
  version    = "0.1.1"
  values     = [file("${path.module}/values/siyuan-values.yaml")]
  depends_on = [kubernetes_namespace.apps]
  timeout    = 600

}
