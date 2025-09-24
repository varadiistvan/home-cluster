resource "kubernetes_secret" "registry_pass" {
  metadata {
    namespace = "default"
    name      = "registry-pass"
  }

  data = {
    ".dockerconfigjson" = jsonencode({
      auths = {
        "registry.stevevaradi.me" = {
          auth = base64encode("stevev:${var.home_registry_password}")
        },
        "harbor.stevevaradi.me" = {
          auth = base64encode("stevev:${var.home_registry_password}")
        }
      }
    })
  }

  type = "kubernetes.io/dockerconfigjson"
}


resource "helm_release" "reloader" {
  name       = "reloader"
  namespace  = "default"
  chart      = "reloader"
  repository = "https://stakater.github.io/stakater-charts"
  version    = "2.2.3"
  values     = [file("${path.module}/reloader-values.yaml")]

  depends_on = [kubernetes_secret.registry_pass]
}
