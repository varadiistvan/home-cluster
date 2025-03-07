resource "kubernetes_secret" "postgres_auth" {
  metadata {
    name      = "postgres-auth"
    namespace = kubernetes_namespace.apps.metadata[0].name
  }
  data = {
    adminpass       = "bruh4"
    userpass        = var.postgres_apps_password
    replicationpass = "bruh3"
  }
}

resource "helm_release" "postgres" {
  name       = "postgres"
  namespace  = kubernetes_namespace.apps.metadata[0].name
  chart      = "postgresql"
  repository = "oci://registry-1.docker.io/bitnamicharts/"
  version    = "16.4.5"
  values     = [file("${path.module}/values/postgres-values.yaml")]
  depends_on = [kubernetes_namespace.apps, kubernetes_secret.postgres_auth, kubernetes_secret.registry_pass]

  set {
    name  = "primary.initdb.password"
    value = "bruh4"
  }
}

resource "helm_release" "postgres-operator" {
  name       = "postgres-operator"
  namespace  = kubernetes_namespace.apps.metadata[0].name
  chart      = "postgres-operator-chart"
  repository = "oci://registry.stevevaradi.me"
  version    = "0.3.2"

  count = 1

  depends_on = [helm_release.postgres]

  set_list {
    name  = "image.pullSecrets"
    value = [kubernetes_secret.registry_pass.metadata[0].name]
  }

  set {
    name  = "image.tag"
    value = "0.1.38"
  }

}

resource "kubernetes_secret" "immich_password" {
  metadata {
    name      = "postgres-immich"
    namespace = kubernetes_namespace.apps.metadata[0].name
  }

  data = {
    password = "testies"
  }

}

resource "kubectl_manifest" "immich_user" {
  yaml_body = <<YAML
    apiVersion: stevevaradi.me/v1
    kind: PostgresUser
    metadata:
      name: immich-user
      namespace: apps
    spec:
      instance:
        host: postgres-postgresql.apps.svc.cluster.local
        port: 5432
        adminCredentials:
          username: postgres
          secretRef:
            name: postgres_auth
            passwordKey: adminpass
      user:
        username: immich
        secretRef:
          name: postgres-immich
          key: password
        privileges:
          - SUPERUSER
  YAML

  depends_on = [helm_release.postgres-operator, kubernetes_secret.immich_password, helm_release.postgres]
}

resource "time_sleep" "wait_for_postgres" {
  depends_on      = [kubectl_manifest.immich_user]
  create_duration = "10s"
}

resource "kubectl_manifest" "immich_database" {
  yaml_body  = <<YAML
    apiVersion: stevevaradi.me/v1
    kind: PostgresDatabase
    metadata:
      name: immich-database
      namespace: apps
    spec:
      instance:
        host: postgres-postgresql.apps.svc.cluster.local
        port: 5432
        adminCredentials:
          username: postgres
          secretRef:
            name: postgres_auth
            passwordKey: adminpass
      database:
        dbName: immich
        owner: immich
        extensions:
          - earthdistance
          - vectors
          - cube
  YAML
  depends_on = [time_sleep.wait_for_postgres]
}
