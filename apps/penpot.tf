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
    password = random_password.penpot_passwords.result
  }

}

resource "kubectl_manifest" "penpot_user" {
  yaml_body = <<YAML
    apiVersion: stevevaradi.me/v1
    kind: PostgresUser
    metadata:
      name: penpot-user
      namespace: apps
    spec:
      instance:
        host: postgres-postgresql.apps.svc.cluster.local
        port: 5432
        adminCredentials:
          username: postgres
          secretRef:
            name: postgres-auth
            passwordKey: adminpass
      user:
        username: penpot
        secretRef:
          name: postgres-penpot
          key: password
        privileges:
          - SUPERUSER
  YAML

  depends_on = [helm_release.postgres-operator, kubernetes_secret.penpot_password, helm_release.postgres]
}

resource "time_sleep" "wait_for_penpot_user" {
  depends_on      = [kubectl_manifest.penpot_user]
  create_duration = "10s"
}

resource "kubectl_manifest" "penpot_database" {
  yaml_body  = <<YAML
    apiVersion: stevevaradi.me/v1
    kind: PostgresDatabase
    metadata:
      name: penpot-database
      namespace: apps
    spec:
      instance:
        host: postgres-postgresql.apps.svc.cluster.local
        port: 5432
        adminCredentials:
          username: postgres
          secretRef:
            name: postgres-auth
            passwordKey: adminpass
      database:
        dbName: penpot
        owner: penpot
        extensions: []
  YAML
  depends_on = [time_sleep.wait_for_penpot_user]
}

resource "time_sleep" "penpot_wait" {
  create_duration = "10s"

  depends_on = [kubectl_manifest.penpot_database]
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
  version    = "0.25.0"
  values     = [file("${path.module}/values/penpot-values.yaml")]
  depends_on = [kubernetes_namespace.apps, kubernetes_secret.penpot_api_key, time_sleep.penpot_wait, kubernetes_secret.penpot_redis_uri]
  timeout    = 600

  set_sensitive = [{
    name  = "config.postgresql.password"
    value = random_password.penpot_passwords.result
  }]
}


