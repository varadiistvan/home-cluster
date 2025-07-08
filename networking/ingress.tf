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

# resource "kubernetes_namespace" "metallb" {
#   metadata {
#     name = "metallb-system"
#   }
# }
#
# resource "helm_release" "metallb" {
#   name       = "lb"
#   namespace  = kubernetes_namespace.metallb.metadata[0].name
#   chart      = "metallb"
#   version    = "0.15.2"
#   repository = "https://metallb.github.io/metallb"
#   # values     = [file("${path.module}/metallb-values.yaml")]
#   timeout    = 600
#   depends_on = [kubernetes_namespace.metallb]
# }
#
# resource "kubectl_manifest" "ips" {
#   yaml_body  = <<YAML
#     apiVersion: metallb.io/v1beta1
#     kind: IPAddressPool
#     metadata:
#       name: first-pool
#       namespace: ${kubernetes_namespace.metallb.metadata[0].name}
#     spec:
#       # A list of IP address ranges over which MetalLB has
#       # authority. You can list multiple ranges in a single pool, they
#       # will all share the same settings. Each range can be either a
#       # CIDR prefix, or an explicit start-end range of IPs.
#       addresses:
#       - 192.168.0.145/32
#   YAML
#   depends_on = [helm_release.metallb]
# }
#
# resource "kubectl_manifest" "advertisement" {
#   yaml_body  = <<YAML
#     apiVersion: metallb.io/v1beta1
#     kind: L2Advertisement
#     metadata:
#       name: first-pool-l2advertisment
#       namespace: ${kubernetes_namespace.metallb.metadata[0].name}
#     spec:
#       ipAddressPools:
#       - first-pool
#   YAML
#   depends_on = [helm_release.metallb]
# }
#
