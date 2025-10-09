resource "kubernetes_config_map" "copyparty_config" {
  metadata {
    name      = "copyparty-config"
    namespace = kubernetes_namespace.apps.id
  }
  data = {
    "copyparty.conf" = <<-YAML
      [global]
      e2dsa
      e2ts
      ansi
      qr

      [accounts]
      stevev: ${var.copyparty_password}

      [/]
        ./root
        accs:
          A: stevev
    YAML
  }
}

resource "helm_release" "copyparty" {
  name       = "copyparty"
  namespace  = kubernetes_namespace.apps.id
  repository = "oci://ghcr.io/danielr1996"
  chart      = "copyparty"
  values     = [file("${path.module}/values/copyparty-values.yaml")]
  version    = "0.5.1"

  set = [{
    name  = "existingConfigMap"
    value = kubernetes_config_map.copyparty_config.metadata[0].name
  }]

  lifecycle {
    ignore_changes = [metadata]
  }
}
