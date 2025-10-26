resource "random_password" "planka_password" {
  length           = 24
  special          = true
  override_special = "-._~" # only unreserved symbols
  min_upper        = 1
  min_lower        = 1
  min_numeric      = 1
  min_special      = 1
}

resource "kubernetes_secret" "planka_password" {
  metadata {
    name      = "planka-password"
    namespace = kubernetes_namespace.apps.id
    labels = {
      "cnpg.io/reload" = "true"
    }
  }

  type = "kubernetes.io/basic-auth"

  data = {
    username = "planka"
    password = random_password.planka_password.result
  }

}

resource "kubectl_manifest" "planka_db" {
  yaml_body = <<-YAML
    apiVersion: postgresql.cnpg.io/v1
    kind: Database
    metadata:
      name: planka-db
      namespace: apps
    spec:
      cluster:
        name: ${kubectl_manifest.cnpg_cluster.name}
      name: planka
      owner: planka
      databaseReclaimPolicy: delete
      # CNPG will create required extensions if the binaries exist in the image
      extensions: []
  YAML
}


resource "random_id" "token" {
  byte_length = 45
}

resource "kubernetes_secret" "planka_admin" {
  metadata {
    name      = "planka-admin"
    namespace = kubernetes_namespace.apps.id
  }
  data = {
    username = "stevev"
    password = var.copyparty_password
  }
}

resource "kubernetes_secret" "planka_appkey" {
  metadata {
    name      = "planka-appkey"
    namespace = kubernetes_namespace.apps.id
  }
  data = { key = random_id.token.b64_std }
}

resource "kubernetes_secret" "planka_dburi" {
  metadata {
    name      = "planka-dburi"
    namespace = kubernetes_namespace.apps.id
  }
  data = {
    uri = "postgresql://planka:${random_password.planka_password.result}@pg-cnpg-rw.apps.svc.cluster.local:5432/planka"
  }
}


resource "helm_release" "planka" {
  name       = "planka"
  namespace  = kubernetes_namespace.apps.metadata[0].name
  chart      = "planka"
  version    = "1.1.0"
  repository = "https://plankanban.github.io/planka"
  values     = [file("${path.module}/values/planka-values.yaml")]
  timeout    = 300
  depends_on = [kubernetes_namespace.apps]

  set_sensitive = [
    {
      name  = "existingDburlSecret"
      value = kubernetes_secret.planka_dburi.metadata[0].name
    },
    {
      name  = "existingAdminCredsSecret"
      value = kubernetes_secret.planka_admin.metadata[0].name
    },
    {
      name  = "existingSecretkeySecret"
      value = kubernetes_secret.planka_appkey.metadata[0].name
    },
  ]

  lifecycle {
    ignore_changes = [metadata]
  }
}


