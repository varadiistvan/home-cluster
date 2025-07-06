resource "helm_release" "cyberchef" {
  name       = "cyberchef"
  namespace  = kubernetes_namespace.apps.id
  repository = "https://charts.obeone.cloud"
  chart      = "cyberchef"
  values     = [file("${path.module}/values/cyberchef-values.yaml")]
  version    = "1.3.4"
}
