# resource "random_password" "mongodb_password" {
#   length  = 16
#   special = true
# }
#
# resource "random_password" "mongodb_replicaset_key" {
#   length  = 64
#   special = false
# }
#
#
# resource "kubernetes_secret" "mongodb_auth" {
#   metadata {
#     name      = "mongodb-auth"
#     namespace = kubernetes_namespace.apps.metadata[0].name
#   }
#   data = {
#     mongodb-root-password   = random_password.mongodb_password.result
#     mongodb-replica-set-key = random_password.mongodb_replicaset_key.result
#   }
# }
#
# resource "helm_release" "mongodb" {
#   name       = "mongodb"
#   namespace  = kubernetes_namespace.apps.metadata[0].name
#   chart      = "mongodb"
#   repository = "oci://registry-1.docker.io/bitnamicharts/"
#   version    = "16.5.45"
#   values     = [file("${path.module}/values/mongodb-values.yaml")]
#   depends_on = [kubernetes_namespace.apps, kubernetes_secret.mongodb_auth]
#
#   set_sensitive = [{
#     name  = "auth.existingSecret"
#     value = kubernetes_secret.mongodb_auth.metadata[0].name
#   }]
# }

resource "helm_release" "mongodb_community_operator" {
  name       = "mongodb-community-operator"
  namespace  = kubernetes_namespace.apps.metadata[0].name
  repository = "https://mongodb.github.io/helm-charts"
  chart      = "community-operator"
  version    = "0.13.0"

  values = [file("${path.module}/values/mongodb-operator-values.yaml")]

}


