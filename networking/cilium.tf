resource "helm_release" "cilium" {
  name       = "cilium"
  namespace  = "kube-system"
  chart      = "cilium"
  version    = "1.17.5"
  repository = "https://helm.cilium.io/"
  values     = [file("${path.module}/cilium-values.yaml")]
  timeout    = 600
}

