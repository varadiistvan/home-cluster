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

resource "time_sleep" "wait_for_immich_user" {
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
  depends_on = [time_sleep.wait_for_immich_user]
}

resource "time_sleep" "immich_wait" {
  create_duration = "10s"

  depends_on = [kubectl_manifest.immich_database]
}

resource "kubernetes_persistent_volume_claim" "immich_pvc" {
  metadata {
    name      = "immich-pvc"
    namespace = kubernetes_namespace.apps.metadata[0].name
  }
  spec {
    access_modes = ["ReadWriteOnce"]
    resources {
      requests = {
        storage = "100Gi"
      }
    }
    storage_class_name = "nfs-csi"
  }
}

resource "helm_release" "immich" {
  name       = "immich"
  namespace  = kubernetes_namespace.apps.metadata[0].name
  chart      = "immich"
  version    = "0.9.3"
  repository = "https://immich-app.github.io/immich-charts"
  values     = [file("${path.module}/values/immich-values.yaml")]
  depends_on = [kubernetes_namespace.apps, helm_release.redis, time_sleep.immich_wait, kubernetes_persistent_volume_claim.immich_pvc]

  set {
    name  = "image.tag"
    value = "v1.132.3"
  }

  set {
    name  = "env.REDIS_HOSTNAME"
    value = "${helm_release.redis.name}-master"
  }

  set {
    name  = "env.REDIS_PASSWORD"
    value = "assword"
  }



  set {
    name  = "env.DB_HOSTNAME"
    value = "${helm_release.postgres.name}-postgresql"
  }

  set {
    name  = "env.DB_USERNAME"
    value = "immich"
  }

  set {
    name  = "env.DB_DATABASE_NAME"
    value = "immich"
  }

  set {
    name  = "env.DB_PASSWORD"
    value = kubernetes_secret.immich_password.data.password
  }

  set {
    name  = "immich.persistence.library.existingClaim"
    value = kubernetes_persistent_volume_claim.immich_pvc.metadata[0].name
  }

}


