resource "kubernetes_namespace" "ingress" {
  metadata {
    name = "ingress-nginx"
  }
}

resource "helm_release" "ingress" {
  name       = "ingress"
  namespace  = kubernetes_namespace.ingress.metadata[0].name
  chart      = "ingress-nginx"
  version    = "4.13.0"
  repository = "https://kubernetes.github.io/ingress-nginx"
  values     = [file("${path.module}/ingress-nginx-values.yaml")]
  timeout    = 500
  depends_on = [
    helm_release.cert_manager,
    # kubectl_manifest.advertisement, 
    kubernetes_namespace.ingress
  ]
}
