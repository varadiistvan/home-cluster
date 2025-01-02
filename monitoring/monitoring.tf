terraform {
  required_providers {
    helm = {
      source = "hashicorp/helm"
    }
    kubernetes = {
      source = "hashicorp/kubernetes"
    }
    kubectl = {
      source = "gavinbunney/kubectl"
    }
  }
}

resource "kubernetes_namespace" "monitoring" {
  metadata {
    name = "monitoring"
  }
}


# resource "kubernetes_secret" "loki_credentials" {
#   metadata {
#     name      = "loki-credentials"
#     namespace = "monitoring"
#   }
#
#   data = {
#     accountKey : var.loki_storage_credentials
#   }
#
#   type = "Opaque"
#
#   depends_on = [kubernetes_namespace.monitoring]
# }

# resource "kubernetes_secret" "grafana" {
#   metadata {
#     name      = "grafana"
#     namespace = "monitoring"
#   }
#
#   data = {
#     admin-password = var.grafana_admin_password
#     admin-user     = "admin"
#   }
#
#   type = "Opaque"
#
#   depends_on = [kubernetes_namespace.monitoring]
# }


# resource "kubernetes_secret" "grafana_postmark" {
#   metadata {
#     name      = "grafana-postmark"
#     namespace = "monitoring"
#   }
#
#   data = {
#     password = var.grafana_postmark
#     username = var.grafana_postmark
#   }
#
#   type = "Opaque"
#
#   depends_on = [kubernetes_namespace.monitoring]
# }


# resource "helm_release" "melodic-sky" {
#   name       = "melodic-sky"
#   namespace  = "monitoring"
#   chart      = "loki"
#   version    = "6.16.0"
#   repository = "https://grafana.github.io/helm-charts"
#   values     = [file("${path.module}/melodic-sky-values.yaml")]
#   depends_on = [kubernetes_namespace.monitoring, kubernetes_secret.loki_credentials]
#
# set_sensitive {
#   name  = "loki.storage.azure.accountkey"
#   value = var.loki_storage_credentials
# }
#
# }


# resource "helm_release" "talented-stew" {
#   name       = "talented-stew"
#   namespace  = "monitoring"
#   chart      = "promtail"
#   version    = "6.16.6"
#   repository = "https://grafana.github.io/helm-charts"
#   values     = [file("${path.module}/talented-stew-values.yaml")]
#   depends_on = [kubernetes_namespace.monitoring]
# }

# resource "kubernetes_storage_class" "managed_premium_retained" {
#   storage_provisioner = "disk.csi.azure.com"
#   metadata {
#     name = "managed-premium-retain"
#   }
#   parameters = {
#     CachingMode        = "ReadOnly"
#     Kind               = "Managed"
#     Storageaccounttype = "Premium_LRS"
#   }
#   reclaim_policy      = "Retain"
#   volume_binding_mode = "WaitForFirstConsumer"
# }

# resource "helm_release" "wonderful-kudu" {
#   name       = "wonderful-kudu"
#   namespace  = "monitoring"
#   chart      = "grafana"
#   version    = "8.5.1"
#   repository = "https://grafana.github.io/helm-charts"
#   values     = [file("${path.module}/wonderful-kudu-values.yaml")]
#   depends_on = [kubernetes_namespace.monitoring, kubernetes_secret.grafana, kubernetes_storage_class.managed_premium_retained]
#   set {
#     name  = "grafana\\.ini.server.domain"
#     value = "grafana.stevevaradi.me"
#   }
#   set {
#     name  = "grafana\\.ini.server.root_url"
#     value = "https://grafana.stevevaradi.me/"
#   }
#   set {
#     name  = "ingress.hosts"
#     value = "{grafana.stevevaradi.me}"
#   }
#   set {
#     name  = "ingress.tls[0].hosts"
#     value = "{grafana.stevevaradi.me}"
#   }
#   set {
#     name  = "ingress.tls[0].secretName"
#     value = "grafana-tls"
#   }
# }

resource "kubectl_manifest" "crds" {
  for_each          = fileset("${path.module}/crds", "*.yaml")
  yaml_body         = file("${path.module}/crds/${each.value}")
  server_side_apply = true
}

resource "helm_release" "misty-show" {
  name       = "misty-show"
  namespace  = "monitoring"
  chart      = "kube-prometheus-stack"
  version    = "66.3.1"
  repository = "https://prometheus-community.github.io/helm-charts"
  values     = [file("${path.module}/misty-show-values.yaml")]
  depends_on = [
    kubernetes_namespace.monitoring,
    # helm_release.melodic-sky,
    kubectl_manifest.crds
  ]

  set {
    name  = "crds.enabled"
    value = false
  }
  skip_crds = true

  set_list {
    name  = "prometheus.ingress.hosts"
    value = ["prometheus.stevevaradi.me"]
  }
  set_list {
    name  = "prometheus.ingress.tls[0].hosts"
    value = ["prometheus.stevevaradi.me"]
  }
  set {
    name  = "prometheus.ingress.tls[0].secretName"
    value = "grafana-tls"
  }
}

