
resource "kubernetes_namespace" "cert_manager" {
  metadata {
    name = "cert-manager"
  }
}

resource "helm_release" "cert_manager" {
  name       = "cert-manager"
  namespace  = "cert-manager"
  chart      = "cert-manager"
  version    = "v1.17.2"
  repository = "https://charts.jetstack.io"
  values     = [file("${path.module}/cert-manager-values.yaml")]
  depends_on = [kubernetes_namespace.cert_manager]
}


resource "kubernetes_secret" "cloudflare-api-key" {
  metadata {
    name      = "cloudflare-api-key-secret"
    namespace = kubernetes_namespace.cert_manager.metadata[0].name
  }
  data = {
    api-key : var.cloudflare_api_key
  }
  type = "Opaque"

  depends_on = [kubernetes_namespace.cert_manager]
}


resource "kubectl_manifest" "clusterissuer_letsencrypt" {
  yaml_body = <<YAML
    apiVersion: cert-manager.io/v1
    kind: ClusterIssuer
    metadata:
      name: letsencrypt
    spec:
      acme:
        email: varadiista.1@gmail.com
        server: https://acme-v02.api.letsencrypt.org/directory
        privateKeySecretRef:
          name: letsencrypt
        solvers:
        - dns01:
            cloudflare:
              email: varadiista.1+dash.cloudflare.com@gmail.com
              apiTokenSecretRef:
                key: api-key
                name: cloudflare-api-key-secret
  YAML

  depends_on = [helm_release.cert_manager, kubernetes_secret.cloudflare-api-key]
}

