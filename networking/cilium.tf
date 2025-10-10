locals {
  gateway_api_crds_sha256 = "6a4029e661446d64add866a00ecdc40c14219b68777ab614c5cdaac0adb481f1"
}

data "http" "gateway_api_crds" {
  url = "https://github.com/kubernetes-sigs/gateway-api/releases/download/v1.4.0/standard-install.yaml"

  request_headers = {
    Accept = "text/yaml"
  }

  lifecycle {
    postcondition {
      condition     = contains([200], self.status_code)
      error_message = "Status code invalid"
    }
    postcondition {
      condition     = sha256(base64decode(self.response_body_base64)) == local.gateway_api_crds_sha256
      error_message = "Hash mismatch for Gateway API CRDs (possible MITM or unexpected content)."
    }
  }
}

resource "kubectl_manifest" "gateway_api_crds" {
  for_each = {
    for manifest in provider::kubernetes::manifest_decode_multi(data.http.gateway_api_crds.response_body) :
    "${manifest.kind}--${manifest.metadata.name}" => yamlencode(manifest)
  }

  yaml_body = each.value
}

resource "helm_release" "cilium" {
  name       = "cilium"
  namespace  = "kube-system"
  chart      = "cilium"
  version    = "1.18.2"
  repository = "https://helm.cilium.io/"
  values     = [file("${path.module}/cilium-values.yaml")]
  timeout    = 300

  depends_on = [kubectl_manifest.ca_issuer, kubectl_manifest.gateway_api_crds]
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
