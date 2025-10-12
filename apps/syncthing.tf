locals {
  syncthing_ip = "192.168.0.154"
}

resource "kubectl_manifest" "syncthing_ip_pool" {
  yaml_body = <<-YAML
    apiVersion: cilium.io/v2
    kind: CiliumLoadBalancerIPPool
    metadata:
      name: vip-syncthing
    spec:
      blocks:
        - start: ${local.syncthing_ip}
          stop:  ${local.syncthing_ip}
  YAML
}


resource "helm_release" "syncthing" {
  name       = "syncthing"
  namespace  = kubernetes_namespace.apps.id
  chart      = "syncthing"
  version    = "0.1.0"
  repository = "oci://harbor.stevevaradi.me/stevevaradi"
  values     = [file("${path.module}/values/syncthing-values.yaml")]
  timeout    = 600

  repository_password = var.home_registry_password
  repository_username = "stevev"


  lifecycle {
    ignore_changes = [metadata]
  }
}

