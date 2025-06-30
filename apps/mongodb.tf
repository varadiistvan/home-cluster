resource "random_password" "mongodb_password" {
  length  = 16
  special = true
}

resource "random_password" "mongodb_replicaset_key" {
  length  = 16
  special = true
}


resource "kubernetes_secret" "mongodb_password" {
  metadata {
    name      = "mongodb-auth"
    namespace = kubernetes_namespace.apps.metadata[0].name
  }
  data = {
    mongodb-root-password   = random_password.mongodb_password.result
    mongodb-replica-set-key = random_password.mongodb_replicaset_key.result
  }
}

resource "helm_release" "mongodb" {
  name       = "mongodb"
  namespace  = kubernetes_namespace.apps.metadata[0].name
  chart      = "mongodb"
  repository = "oci://registry-1.docker.io/bitnamicharts/"
  version    = "16.5.27"
  values     = [file("${path.module}/values/mongodb-values.yaml")]
  depends_on = [kubernetes_namespace.apps, kubernetes_secret.mongodb_password]

  set_sensitive {
    name  = "auth.existingSecret"
    value = kubernetes_secret.mongodb_password.metadata[0].name
  }
}
