resource "kubernetes_config_map" "stirling_pdf_config" {
  metadata {
    name      = "stirling-pdf-config"
    namespace = kubernetes_namespace.apps.id
  }

  data = {
    "custom_settings.yml" = <<YAML
      system:
        maxDPI: 4000
    YAML
  }
}

resource "helm_release" "stirling_pdf" {
  name       = "stirling-pdf"
  namespace  = kubernetes_namespace.apps.metadata[0].name
  chart      = "stirling-pdf-chart"
  version    = "2.2.0"
  repository = "https://docs.stirlingpdf.com/Stirling-PDF-chart"
  values     = [file("${path.module}/values/stirling-pdf-values.yaml")]
  timeout    = 600
  depends_on = [kubernetes_namespace.apps, kubernetes_config_map.stirling_pdf_config]

}

