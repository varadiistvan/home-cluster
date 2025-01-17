# resource "helm_release" "immich" {
#   name       = "immich"
#   namespace  = kubernetes_namespace.apps.metadata[0].name
#   chart      = "immich"
#   version    = "2.1.0"
#   repository = "https://immich-app.github.io/immich-charts"
#   values     = [file("${path.module}/values/immich-values.yaml")]
#   timeout    = 600
#   depends_on = [kubernetes_namespace.apps]
# }

