resource "helm_release" "cilium" {
  name       = "cilium"
  namespace  = "kube-system"
  chart      = "cilium"
  version    = "1.18.1"
  repository = "https://helm.cilium.io/"
  values     = [file("${path.module}/cilium-values.yaml")]
  timeout    = 300

  depends_on = [kubectl_manifest.ca_issuer]
}

resource "kubectl_manifest" "main_ingress_ip_pool" {
  yaml_body = <<-YAML
    apiVersion: cilium.io/v2
    kind: CiliumLoadBalancerIPPool
    metadata:
      name: vip-192-168-0-152
    spec:
      blocks:
        - start: "192.168.0.152"
          stop:  "192.168.0.152"
  YAML

  depends_on = [helm_release.cilium]
}

resource "kubectl_manifest" "main_ingresS_l2ap" {
  yaml_body = <<-YAML
    apiVersion: cilium.io/v2alpha1
    kind: CiliumL2AnnouncementPolicy
    metadata:
      name: announce-ingress
    spec:
      loadBalancerIPs: true
      externalIPs: false
  YAML

  depends_on = [kubectl_manifest.main_ingress_ip_pool]
}
