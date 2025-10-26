resource "kubernetes_secret" "immich_password" {
  metadata {
    name      = "postgres-immich"
    namespace = kubernetes_namespace.apps.metadata[0].name
  }

  data = {
    username = "immich"
    password = "testies"
  }

}


resource "kubectl_manifest" "immich_db" {
  yaml_body = <<-YAML
    apiVersion: postgresql.cnpg.io/v1
    kind: Database
    metadata:
      name: immich-db
      namespace: apps
    spec:
      cluster:
        name: ${kubectl_manifest.cnpg_cluster.name}
      name: immich
      owner: immich
      databaseReclaimPolicy: retain
      # CNPG will create required extensions if the binaries exist in the image
      extensions:
        - name: cube
        - name: earthdistance
        # If you're using pgvector, the extension name is "vector" (not "vectors")
        - name: vectors
        - name: vector
        - name: vchord
  YAML

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
  depends_on = [kubernetes_namespace.apps, helm_release.redis, kubernetes_persistent_volume_claim.immich_pvc]

  set = [{
    name  = "env.REDIS_HOSTNAME"
    value = "${helm_release.redis["immich"].name}-master"
    },

    {
      name  = "env.REDIS_PASSWORD"
      value = random_password.redis_passwords["immich"].result
    },

    {
      name  = "env.DB_HOSTNAME"
      value = "pg-cnpg-rw"
    },

    {
      name  = "env.DB_USERNAME"
      value = "immich"
    },

    {
      name  = "env.DB_DATABASE_NAME"
      value = "immich"
    },

    {
      name  = "env.DB_PASSWORD"
      value = kubernetes_secret.immich_password.data.password
    },

    {
      name  = "immich.persistence.library.existingClaim"
      value = kubernetes_persistent_volume_claim.immich_pvc.metadata[0].name
    },
  ]

  lifecycle {
    ignore_changes = [metadata]
  }

}


