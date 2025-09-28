resource "random_password" "convertx_jwt" {
  length  = 16
  special = true
}

resource "kubernetes_secret" "convertx_jwt" {
  metadata {
    name      = "convertx-jwt"
    namespace = kubernetes_namespace.apps.id
  }
  data = {
    JWT_SECRET = random_password.convertx_jwt.result
  }
}

resource "helm_release" "convertx" {
  name                = "convertx"
  namespace           = kubernetes_namespace.apps.id
  repository          = "oci://harbor.stevevaradi.me/stevevaradi"
  chart               = "convertx"
  values              = [file("${path.module}/values/convertx-values.yaml")]
  version             = "0.1.0"
  repository_username = "stevev"
  repository_password = var.home_registry_password

  depends_on = [kubernetes_secret.convertx_jwt]

  lifecycle {
    ignore_changes = [metadata]
  }
}
