resource "kubernetes_secret" "ddns" {
  metadata {
    name      = "ddns-secret"
    namespace = kubernetes_namespace.dns.metadata[0].name
  }
  data = {
    AUTH_KEY  = var.cloudflare_api_key
    NAME      = "stevevaradi.me"
    RECORD_ID = "f4bdc6d5a7ebd571944e80b0e3dd349e"
    ZONE_ID   = "317553688e00ccc4168e216caab44f3a"
  }
}

resource "helm_release" "ddns" {
  name       = "ddns"
  namespace  = kubernetes_namespace.dns.metadata[0].name
  chart      = "kubernetes-cloudflare-ddns"
  version    = "1.0.6"
  repository = "https://charts.kubito.dev"
  values     = [file("${path.module}/ddns-values.yaml")]
  timeout    = 600
}

resource "kubernetes_namespace" "dns" {
  metadata {
    name = "dns"
  }
}

# resource "kubernetes_secret" "cloudflare" {
#   metadata {
#     name      = "cloudflare-api-key"
#     namespace = kubernetes_namespace.dns.metadata[0].name
#   }
#   data = {
#     apiKey = var.cloudflare_api_key
#     email  = "varadiista.1+dash.cloudflare.com@gmail.com"
#   }
# }
# resource "helm_release" "external-dns" {
#   name       = "ex-dns"
#   namespace  = kubernetes_namespace.dns.metadata[0].name
#   chart      = "external-dns"
#   version    = "1.15.0"
#   repository = "https://kubernetes-sigs.github.io/external-dns/"
#   values     = [file("${path.module}/external-dns-values.yaml")]
# }
