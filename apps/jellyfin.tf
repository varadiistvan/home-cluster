resource "helm_release" "jellyfin" {
  name       = "jellyfin"
  namespace  = kubernetes_namespace.apps.metadata[0].name
  chart      = "jellyfin"
  version    = "2.5.0"
  repository = "https://jellyfin.github.io/jellyfin-helm"
  values     = [file("${path.module}/values/jellyfin-values.yaml")]
  timeout    = 600
  depends_on = [kubernetes_namespace.apps]

  lifecycle {
    ignore_changes = [metadata]
  }
}


resource "helm_release" "jellyseerr" {
  name       = "jellyseer"
  namespace  = kubernetes_namespace.apps.metadata[0].name
  chart      = "jellyseerr-chart"
  version    = "2.7.0"
  repository = "oci://ghcr.io/fallenbagel/jellyseerr"
  values     = [file("${path.module}/values/jellyseer-values.yaml")]
  timeout    = 300
  depends_on = [kubernetes_namespace.apps]

  lifecycle {
    ignore_changes = [metadata]
  }
}

