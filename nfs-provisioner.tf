resource "helm_release" "nfs_provisioner" {
  name       = "nfs-provisioner"
  namespace  = "kube-system"
  chart      = "csi-driver-nfs"
  version    = "v4.9.0"
  repository = "https://raw.githubusercontent.com/kubernetes-csi/csi-driver-nfs/master/charts"
  timeout    = 600
  values     = [file("${path.module}/nfs-provisioner-values.yaml")]
}

resource "helm_release" "nfs_provisioner_nolock" {
  name       = "nfs-provisioner-nolock"
  namespace  = "kube-system"
  chart      = "csi-driver-nfs"
  version    = "v4.9.0"
  repository = "https://raw.githubusercontent.com/kubernetes-csi/csi-driver-nfs/master/charts"
  timeout    = 600
  values     = [file("${path.module}/nfs-provisioner-values.yaml")]


  set {
    name  = "storageClass.name"
    value = "nfs-csi-nolock"
  }

  set_list {
    name  = "storageClass.mountOptions"
    value = ["nfsvers=3", "nolock"]
  }

  set {
    name  = "serviceAccount.controller"
    value = "csi-nfs-nolock-controller-sa"
  }

  set {
    name  = "serviceAccount.node"
    value = "csi-nfs-nolock-node-sa"
  }

  set {
    name  = "rbac.name"
    value = "nfs-nolock"
  }

  set {
    name  = "node.name"
    value = "csi-nfs-nolock-node"
  }

  set {
    name  = "controller.name"
    value = "csi-nfs-nolock-controller"
  }

  set {
    name  = "driver.name"
    value = "nfs-nolock.csi.k8s.io"
  }

  set {
    name  = "controller.livenessProbe.healthPort"
    value = "29654"
  }

  set {
    name  = "node.livenessProbe.healthPort"
    value = "29655"
  }

}

resource "helm_release" "nfs_provisioner_retain" {
  name       = "nfs-provisioner-retain"
  namespace  = "kube-system"
  chart      = "csi-driver-nfs"
  version    = "v4.9.0"
  repository = "https://raw.githubusercontent.com/kubernetes-csi/csi-driver-nfs/master/charts"
  timeout    = 600
  values     = [file("${path.module}/nfs-provisioner-values.yaml")]

  set {
    name  = "storageClass.reclaimPolicy"
    value = "Retain"
  }

  set {
    name  = "storageClass.name"
    value = "nfs-csi-retain"
  }

  set {
    name  = "serviceAccount.controller"
    value = "csi-nfs-retain-controller-sa"
  }

  set {
    name  = "serviceAccount.node"
    value = "csi-nfs-retain-node-sa"
  }

  set {
    name  = "rbac.name"
    value = "nfs-retain"
  }

  set {
    name  = "node.name"
    value = "csi-nfs-retain-node"
  }

  set {
    name  = "controller.name"
    value = "csi-nfs-retain-controller"
  }

  set {
    name  = "driver.name"
    value = "nfs-retain.csi.k8s.io"
  }

  set {
    name  = "controller.livenessProbe.healthPort"
    value = "29656"
  }

  set {
    name  = "node.livenessProbe.healthPort"
    value = "29657"
  }

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
