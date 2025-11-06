resource "random_password" "immich_passwords" {
  length  = 16
  special = true
}

resource "kubernetes_secret" "immich_password" {
  metadata {
    name      = "postgres-immich"
    namespace = kubernetes_namespace.apps.metadata[0].name
    labels = {
      "cnpg.io/reload" = "true"
    }
  }

  data = {
    username = "immich"
    password = random_password.immich_passwords.result
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
          version: 0.4.3
      
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
  version    = "0.10.1"
  repository = "https://immich-app.github.io/immich-charts"
  values     = [file("${path.module}/values/immich-values.yaml")]
  depends_on = [kubernetes_namespace.apps, helm_release.redis, kubernetes_persistent_volume_claim.immich_pvc]

  set = [
    {
      name  = "valkey.enabled"
      value = "false"
    },
    {
      name  = "controllers.main.containers.main.env.REDIS_HOSTNAME"
      value = "${helm_release.redis["immich"].name}-master"
    },
    {
      name  = "controllers.main.containers.main.env.DB_HOSTNAME"
      value = "pg-cnpg-rw"
    },
    {
      name  = "controllers.main.containers.main.env.DB_USERNAME"
      value = "immich"
    },
    {
      name  = "controllers.main.containers.main.env.DB_DATABASE_NAME"
      value = "immich"
    },
    {
      name  = "immich.persistence.library.existingClaim"
      value = kubernetes_persistent_volume_claim.immich_pvc.metadata[0].name
    }
  ]

  set_sensitive = [
    {
      name  = "controllers.main.containers.main.env.DB_PASSWORD"
      value = kubernetes_secret.immich_password.data.password
    },
    {
      name  = "controllers.main.containers.main.env.REDIS_PASSWORD"
      value = random_password.redis_passwords["immich"].result
    }
  ]

  lifecycle {
    ignore_changes = [metadata]
  }

}


