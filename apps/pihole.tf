resource "helm_release" "pihole" {
  name       = "pihole"
  namespace  = kubernetes_namespace.apps.metadata[0].name
  chart      = "pihole"
  version    = "2.27.0"
  repository = "https://mojo2600.github.io/pihole-kubernetes/"
  values     = [file("${path.module}/pihole-values.yaml")]
  timeout    = 600
  depends_on = [kubernetes_namespace.apps, kubectl_manifest.advertisement, kubectl_manifest.pihole_ips]
}

resource "kubectl_manifest" "pihole_ips" {
  yaml_body = <<YAML
    apiVersion: metallb.io/v1beta1
    kind: IPAddressPool
    metadata:
      # A name for the address pool. Services can request allocation
      # from a specific address pool using this name.
      name: pihole-pool
      namespace: metallb-system
    spec:
      # A list of IP address ranges over which MetalLB has
      # authority. You can list multiple ranges in a single pool, they
      # will all share the same settings. Each range can be either a
      # CIDR prefix, or an explicit start-end range of IPs.
      addresses:
      - 192.168.0.146/32
  YAML
}

resource "kubectl_manifest" "advertisement" {
  yaml_body = <<YAML
    apiVersion: metallb.io/v1beta1
    kind: L2Advertisement
    metadata:
      name: pihole-l2advertisment
      namespace: metallb-system
    spec:
      ipAddressPools:
      - pihole-pool
  YAML
}
