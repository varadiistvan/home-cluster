resource "helm_release" "syncthing" {
  name       = "syncthing"
  namespace  = kubernetes_namespace.apps.id
  chart      = "syncthing"
  version    = "22.6.0"
  repository = "oci://oci.trueforge.org/truecharts"
  values     = [file("${path.module}/values/syncthing-values.yaml")]
  timeout    = 600

  lifecycle {
    ignore_changes = [metadata]
  }
}

