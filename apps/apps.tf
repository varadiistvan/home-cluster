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
    time = {
      source = "hashicorp/time"
    }
  }
  required_version = "~> 1.10.2"
}

resource "kubernetes_namespace" "apps" {
  metadata {
    name = "apps"
  }
}

resource "kubernetes_secret" "registry_pass" {
  metadata {
    namespace = kubernetes_namespace.apps.metadata[0].name
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

  depends_on = [kubernetes_namespace.apps]
}
