resource "kubernetes_secret" "overleaf_auth" {
  metadata {
    name      = "overleaf-auth"
    namespace = kubernetes_namespace.apps.id
  }

  data = {
    redis-password = random_password.redis_passwords["overleaf"].result
    mongo-url      = "mongodb://root:${urlencode(random_password.mongodb_password.result)}@mongodb-headless/sharelatex?authSource=admin"
  }
}


resource "helm_release" "overleaf" {
  name                = "overleaf"
  namespace           = kubernetes_namespace.apps.id
  repository          = "oci://registry.stevevaradi.me"
  chart               = "overleaf"
  values              = [file("${path.module}/values/overleaf-values.yaml")]
  version             = "0.1.8"
  repository_username = "stevev"
  repository_password = var.home_registry_password

  timeout = 600

  set {
    name  = "forcereload"
    value = "g"
  }

  set {
    name  = "mongo.existingSecret"
    value = kubernetes_secret.overleaf_auth.metadata[0].name
  }

  set {
    name  = "mongo.existingSecretKey"
    value = "mongo-url"
  }

  set {
    name  = "redis.password.existingSecret"
    value = kubernetes_secret.overleaf_auth.metadata[0].name
  }

  set {
    name  = "redis.password.existingSecretKey"
    value = "redis-password"
  }

  set {
    name  = "redis.host"
    value = "${helm_release.redis["overleaf"].name}-master"
  }

}
