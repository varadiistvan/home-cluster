
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
  version    = "0.9.0"
  repository = "https://immich-app.github.io/immich-charts"
  values     = [file("${path.module}/values/immich-values.yaml")]
  depends_on = [kubernetes_namespace.apps, helm_release.redis, time_sleep.immich_wait, kubernetes_persistent_volume_claim.immich_pvc]

  set {
    name  = "env.REDIS_HOSTNAME"
    value = "${helm_release.redis.name}-master.${kubernetes_namespace.apps.metadata[0].name}.svc.cluster.local"
  }

  set {
    name  = "env.REDIS_PASSWORD"
    value = "assword"
  }

  set {
    name  = "env.REDIS_DBINDEX"
    value = "\"0\""
  }



  set {
    name  = "env.DB_HOSTNAME"
    value = "${helm_release.postgres.name}-postgresql.${kubernetes_namespace.apps.metadata[0].name}.svc.cluster.local"
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

