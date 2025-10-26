resource "random_password" "penpot_passwords" {
  length  = 16
  special = true
}

resource "kubernetes_secret" "penpot_password" {
  metadata {
    name      = "postgres-penpot"
    namespace = kubernetes_namespace.apps.metadata[0].name
  }

  data = {
    username = "penpot"
    password = random_password.penpot_passwords.result
  }

}

resource "kubectl_manifest" "penpot_db" {
  yaml_body = <<-YAML
    apiVersion: postgresql.cnpg.io/v1
    kind: Database
    metadata:
      name: penpot-db
      namespace: apps
    spec:
      cluster:
        name: ${kubectl_manifest.cnpg_cluster.name}
      name: penpot
      owner: penpot
      databaseReclaimPolicy: retain
      # CNPG will create required extensions if the binaries exist in the image
      extensions: []
  YAML

  depends_on = [helm_release.cnpg_operator]
}

resource "kubernetes_secret" "penpot_api_key" {
  metadata {
    name      = "penpot-api-key"
    namespace = kubernetes_namespace.apps.metadata[0].name
  }

  data = {
    key : var.penpot_api_key
  }
}

resource "kubernetes_secret" "penpot_redis_uri" {
  metadata {
    name      = "penpot-redis-uri"
    namespace = kubernetes_namespace.apps.metadata[0].name
  }

  data = {
    uri : "redis://:${random_password.redis_passwords["penpot"].result}@${helm_release.redis["penpot"].name}-master:6379/0"
  }

}

resource "helm_release" "penpot" {
  name       = "penpot"
  namespace  = kubernetes_namespace.apps.metadata[0].name
  chart      = "penpot"
  repository = "https://helm.penpot.app"
  version    = "0.28.0"
  values     = [file("${path.module}/values/penpot-values.yaml")]
  depends_on = [kubernetes_namespace.apps, kubernetes_secret.penpot_api_key, kubernetes_secret.penpot_redis_uri]
  timeout    = 600

  set_sensitive = [{
    name  = "config.postgresql.password"
    value = random_password.penpot_passwords.result
  }]

  lifecycle {
    ignore_changes = [metadata]
  }
}


