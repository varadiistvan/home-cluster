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
  required_version = "~> 1.10.2"
}

resource "kubernetes_namespace" "apps" {
  metadata {
    name = "apps"
  }
}
