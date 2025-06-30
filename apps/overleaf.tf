resource "kubernetes_secret" "overleaf_auth" {
  metadata {
    name      = "overleaf-auth"
    namespace = kubernetes_namespace.apps.id
  }

  data = {
    redis-url = ""
    mongo-url = ""
  }
}


# resource "helm_release" "overleaf" {
#   name                = "overleaf"
#   namespace           = kubernetes_namespace.apps.id
#   repository          = "oci://registry.stevevaradi.me"
#   chart               = "overleaf"
#   values              = [file("${path.module}/values/overleaf-values.yaml")]
#   repository_username = "stevev"
#   repository_password = var.home_registry_password
#
#   set {
#     name  = "mongo.existingSecret"
#     value = kubernetes_secret.overleaf_auth.metadata[0].name
#   }
#
#   set {
#     name  = "mongo.existingSecretKey"
#     value = "mongo-url"
#   }
#
#   set {
#     name  = "redis.existingSecret"
#     value = kubernetes_secret.overleaf_auth.metadata[0].name
#   }
#
#   set {
#     name  = "redis.existingSecretKey"
#     value = "redis-url"
#   }
#
# }
