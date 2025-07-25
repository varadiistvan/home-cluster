resource "helm_release" "stirling_pdf" {
  name       = "stirling-pdf"
  namespace  = kubernetes_namespace.apps.metadata[0].name
  chart      = "stirling-pdf-chart"
  version    = "2.1.0"
  repository = "https://docs.stirlingpdf.com/Stirling-PDF-chart"
  values     = [file("${path.module}/values/stirling-pdf-values.yaml")]
  timeout    = 600
  depends_on = [kubernetes_namespace.apps]
}

