terraform {
  required_providers {
    helm = {
      source  = "hashicorp/helm"
      version = "2.16.1"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "2.33.0"
    }
    kubectl = {
      source  = "gavinbunney/kubectl"
      version = "1.14.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "3.6.3"
    }
  }

  required_version = "~> 1.10.2"
}


provider "kubectl" {
  host                   = var.kubernetes_host
  client_certificate     = base64decode(var.client_certificate)
  client_key             = base64decode(var.client_key)
  cluster_ca_certificate = base64decode(var.cluster_ca_certificate)

  load_config_file = false
}

provider "helm" {

  kubernetes {
    host                   = var.kubernetes_host
    client_certificate     = base64decode(var.client_certificate)
    client_key             = base64decode(var.client_key)
    cluster_ca_certificate = base64decode(var.cluster_ca_certificate)
  }

  ## This feature is currently bugged with some charts that include CRDs, PR to look out for is
  ## https://github.com/hashicorp/terraform-provider-helm/pull/1396

  # experiments {
  #   manifest = true
  # }
}

provider "kubernetes" {
  host                   = var.kubernetes_host
  client_certificate     = base64decode(var.client_certificate)
  client_key             = base64decode(var.client_key)
  cluster_ca_certificate = base64decode(var.cluster_ca_certificate)
}
module "networking" {
  source = "./networking/"

  cloudflare_api_key = var.cloudflare_api_key

  providers = {
    kubernetes = kubernetes
    helm       = helm
  }

}


# module "monitoring" {
#   source     = "./monitoring/"
#   depends_on = [module.networking]
#
#   domain = ""
#
#   providers = {
#     kubernetes = kubernetes
#     helm       = helm
#     kubectl    = kubectl
#   }
# }