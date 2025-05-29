terraform {
  required_providers {
    helm = {
      source = "hashicorp/helm"
    }
    kubernetes = {
      source = "hashicorp/kubernetes"
    }
    kubectl = {
      source = "alekc/kubectl"
    }
  }
}

resource "kubernetes_namespace" "monitoring" {
  metadata {
    name = "monitoring"
  }
}


resource "kubernetes_secret" "registry_pass" {
  metadata {
    namespace = kubernetes_namespace.monitoring.metadata[0].name
    name      = "registry-pass"
  }

  data = {
    ".dockerconfigjson" = jsonencode({
      auths = {
        "registry.stevevaradi.me" = {
          auth = base64encode("stevev:${var.home_registry_password}")
        }
      }
    })
  }

  type = "kubernetes.io/dockerconfigjson"

  depends_on = [kubernetes_namespace.monitoring]
}

# resource "kubernetes_secret" "grafana_password" {
#   metadata {
#     name      = "grafana-password"
#     namespace = kubernetes_namespace.monitoring.metadata[0].name
#   }
# }

resource "helm_release" "misty_show" {
  name       = "misty-show"
  namespace  = kubernetes_namespace.monitoring.metadata[0].name
  chart      = "kube-prometheus-stack"
  version    = "72.6.4"
  repository = "https://prometheus-community.github.io/helm-charts"
  values     = [file("${path.module}/misty-show-values.yaml")]
  depends_on = [
    kubernetes_namespace.monitoring,
    # helm_release.melodic-sky,
  ]

  set {
    name  = "crds.enabled"
    value = true
  }

  set_sensitive {
    name  = "grafana.adminPassword"
    value = var.grafana_password
  }

}


resource "helm_release" "pi5_monitor" {
  name       = "pi5-monitor"
  namespace  = kubernetes_namespace.monitoring.metadata[0].name
  chart      = "pi5-monitor"
  version    = "0.1.5"
  repository = "oci://registry.stevevaradi.me"

  set_list {
    name  = "image.pullSecrets"
    value = ["registry-pass"]
  }

  set {
    name  = "image.tag"
    value = "0.1.1"
  }

  depends_on = [kubernetes_secret.registry_pass, helm_release.misty_show]

}
