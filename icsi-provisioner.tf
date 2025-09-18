resource "helm_release" "iscsi_provisioner" {
  name       = "iscsi-provisioner"
  namespace  = "kube-system"
  chart      = "csi-iscsi-provisioner-chart"
  version    = "0.9.0"
  repository = "oci://harbor.stevevaradi.me/stevevaradi"
  timeout    = 600
  values     = [file("${path.module}/iscsi-provisioner-values.yaml")]

  depends_on = [kubernetes_secret.registry_pass, kubernetes_secret.iscsi_provisioner_token]
}

resource "kubernetes_secret" "iscsi_provisioner_token" {
  metadata {
    namespace = "kube-system"
    name      = "iscsi-provisioner-token"
  }

  data = {
    token = var.iscsi_provisioner_token
  }

}

resource "kubernetes_secret" "registry_pass" {
  metadata {
    namespace = "kube-system"
    name      = "registry-pass"
  }

  data = {
    ".dockerconfigjson" = jsonencode({
      auths = {
        "registry.stevevaradi.me" = {
          auth = base64encode("stevev:${var.home_registry_password}")
        },
        "harbor.stevevaradi.me" = {
          auth = base64encode("stevev:${var.home_registry_password}")
        }
      }
    })
  }

  type = "kubernetes.io/dockerconfigjson"

}
