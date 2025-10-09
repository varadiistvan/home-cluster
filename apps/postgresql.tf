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
  version    = "16.7.27"
  values     = [file("${path.module}/values/postgres-values.yaml")]
  depends_on = [kubernetes_namespace.apps, kubernetes_secret.postgres_auth, kubernetes_secret.registry_pass]

  set = [{
    name  = "primary.initdb.password"
    value = "bruh4"
  }]

  lifecycle {
    ignore_changes = [metadata]
  }
}

resource "helm_release" "cnpg_operator" {
  name       = "cnpg"
  namespace  = kubernetes_namespace.apps.id
  repository = "https://cloudnative-pg.github.io/charts"
  chart      = "cloudnative-pg"
  version    = "0.26.0"
  values = [
    <<-YAML
      image:
        repository: harbor.stevevaradi.me/ghcr/cloudnative-pg/cloudnative-pg
      imagePullSecrets:
        - name: registry-pass
    YAML
  ]
}

resource "kubernetes_secret" "cnpg_superuser" {
  metadata {
    name      = "cnpg-superuser"
    namespace = kubernetes_namespace.apps.id
  }
  type = "kubernetes.io/basic-auth"
  data = {
    username = "postgres"
    password = "bruh4"
  }
}

resource "kubernetes_secret" "cnpg_app_user" {
  metadata {
    name      = "cnpg-apps"
    namespace = kubernetes_namespace.apps.id
  }
  type = "kubernetes.io/basic-auth"
  data = {
    username = "apps"
    password = var.postgres_apps_password
  }
}

resource "kubernetes_secret" "cnpg_repl" {
  metadata {
    name      = "cnpg-repl"
    namespace = kubernetes_namespace.apps.id
  }
  type = "kubernetes.io/basic-auth"
  data = {
    username = "repl_user"
    password = "bruh3"
  }
}

resource "kubectl_manifest" "cnpg_cluster" {
  yaml_body = <<-YAML
    apiVersion: postgresql.cnpg.io/v1
    kind: Cluster
    metadata:
      name: pg-cnpg
      namespace: apps
    spec:
      instances: 1
      imageName: harbor.stevevaradi.me/stevevaradi/vector-pg:16
      imagePullPolicy: Always
      imagePullSecrets:
        - name: registry-pass

      storage:
        size: 8Gi
        storageClass: iscsi-csi

      postgresql:
        shared_preload_libraries:
          - pgaudit
          - vchord

      bootstrap:
        pg_basebackup:
          source: bitnami-src
          # optional: create/ensure an app DB/user after recovery completes
          # database: app
          # owner: app
          # secret:
          #   name: app-secret

      externalClusters:
        - name: bitnami-src
          connectionParameters:
            host: postgres-postgresql.apps.svc.cluster.local
            port: "5432"
            user: repl_user
            dbname: postgres
            sslmode: disable   # consider prefer/require later
          password:
            name: cnpg-repl
            key: password

      monitoring:
        enablePodMonitor: true

  YAML

  depends_on = [helm_release.cnpg_operator]
}


resource "helm_release" "postgres-operator" {
  name       = "postgres-operator"
  namespace  = kubernetes_namespace.apps.metadata[0].name
  chart      = "postgres-operator-chart"
  repository = "oci://harbor.stevevaradi.me/stevevaradi"
  version    = "0.3.2"

  count = 1

  depends_on = [helm_release.postgres]

  set_list = [{
    name  = "image.pullSecrets"
    value = [kubernetes_secret.registry_pass.metadata[0].name]
  }]

  set = [
    {
      name  = "image.tag"
      value = "0.1.38"
    },
    {
      name  = "image.registry"
      value = "harbor.stevevaradi.me/stevevaradi"
    }
  ]

  lifecycle {
    ignore_changes = [metadata]
  }
}
