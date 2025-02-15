resource "helm_release" "nfs_provisioner" {
  name       = "nfs-provisioner"
  namespace  = "kube-system"
  chart      = "csi-driver-nfs"
  version    = "v4.9.0"
  repository = "https://raw.githubusercontent.com/kubernetes-csi/csi-driver-nfs/master/charts"
  timeout    = 600
  values     = [file("${path.module}/nfs-provisioner-values.yaml")]
}


resource "kubernetes_storage_class" "nfs_retain" {
  metadata {
    name = "nfs-csi-retain"
  }
  storage_provisioner = "nfs.csi.k8s.io"
  mount_options       = ["nfsvers=4"]
  volume_binding_mode = "Immediate"
  reclaim_policy      = "Retain"
  parameters = {
    mountPermissions = "777"
    server           = "192.168.0.151"
    share            = "/pvcs"
    subDir           = "/$${pv.metadata.name}"
  }

  depends_on = [helm_release.nfs_provisioner]
}

# resource "helm_release" "nfs_provisioner_easy" {
#   name       = "nfs-provisioner-easy"
#   namespace  = "kube-system"
#   chart      = "nfs-subdir-external-provisioner"
#   version    = "4.0.18"
#   repository = "https://kubernetes-sigs.github.io/nfs-subdir-external-provisioner/"
#   timeout    = 600
#
#   values = [
#     <<YAML
#       nfs:
#         server: 192.168.0.151
#         path: /export/pvcs
#         mountOptions:
#           - nfsvers=3
#       storageClass:
#         defaultClass: true
#         name: nfs-provisioner
#     YAML
#   ]
# }
