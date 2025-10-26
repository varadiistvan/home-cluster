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
    username          = "mealie"
    password          = random_password.mealie_postgres_password.result
    POSTGRES_PASSWORD = random_password.mealie_postgres_password.result
  }
}


resource "kubectl_manifest" "mealie_db" {
  yaml_body = <<-YAML
    apiVersion: postgresql.cnpg.io/v1
    kind: Database
    metadata:
      name: mealie-db
      namespace: apps
    spec:
      cluster:
        name: ${kubectl_manifest.cnpg_cluster.name}
      name: mealie
      owner: mealie
      extensions: []
  YAML

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

  depends_on = [kubectl_manifest.mealie_db]

  lifecycle {
    ignore_changes = [metadata]
  }
}
