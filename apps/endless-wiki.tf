resource "kubectl_manifest" "endless_tls" {
  yaml_body = <<-YAML
    apiVersion: cert-manager.io/v1
    kind: Certificate
    metadata:
      name: endless-cert
      namespace: ${kubernetes_namespace.apps.id}
    spec:
      secretName: endless-tls
      issuerRef:
        kind: ClusterIssuer
        name: letsencrypt
      commonName: wiki.stevevaradi.me
      dnsNames:
        - wiki.stevevaradi.me

  YAML
}

resource "helm_release" "endless-wiki" {
  name       = "wiki"
  namespace  = kubernetes_namespace.apps.id
  chart      = "endless-wiki"
  repository = "oci://registry.stevevaradi.me"
  version    = "0.1.6"
  values     = [file("${path.module}/values/endless-wiki-values.yaml")]

  repository_username = "stevev"
  repository_password = var.home_registry_password

  timeout = 600
}

