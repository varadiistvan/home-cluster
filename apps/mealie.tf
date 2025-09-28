resource "random_password" "mealie_postgres_password" {
  length  = 16
  special = true
}

resource "kubernetes_secret" "mealie_postgres" {
  metadata {
    name      = "mealie-postgres"
    namespace = kubernetes_namespace.apps.id
  }
  data = {
    POSTGRES_PASSWORD = random_password.mealie_postgres_password.result
  }
}

resource "kubectl_manifest" "mealie_user" {
  yaml_body = <<YAML
    apiVersion: stevevaradi.me/v1
    kind: PostgresUser
    metadata:
      name: mealie-user
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
        username: mealie
        secretRef:
          name: mealie-postgres
          key: POSTGRES_PASSWORD
        privileges:
          - SUPERUSER
  YAML

  depends_on = [helm_release.postgres-operator, kubernetes_secret.mealie_postgres, helm_release.postgres]
}

resource "time_sleep" "wait_for_mealie_user" {
  depends_on      = [kubectl_manifest.mealie_user]
  create_duration = "10s"
}

resource "kubectl_manifest" "mealie_database" {
  yaml_body  = <<YAML
    apiVersion: stevevaradi.me/v1
    kind: PostgresDatabase
    metadata:
      name: mealie-database
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
        dbName: mealie
        owner: mealie
        extensions: []
  YAML
  depends_on = [time_sleep.wait_for_mealie_user]
}


resource "helm_release" "mealie" {
  name                = "mealie"
  namespace           = kubernetes_namespace.apps.id
  repository          = "oci://harbor.stevevaradi.me/stevevaradi"
  chart               = "mealie"
  values              = [file("${path.module}/values/mealie-values.yaml")]
  version             = "0.1.1"
  repository_username = "stevev"
  repository_password = var.home_registry_password

  depends_on = [kubectl_manifest.mealie_database]

  lifecycle {
    ignore_changes = [metadata]
  }
}
