terraform {
  required_providers {
    helm = {
      source  = "hashicorp/helm"
      version = "2.17.0"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "2.36.0"
    }
    kubectl = {
      source  = "alekc/kubectl"
      version = "2.1.3"
    }
    random = {
      source  = "hashicorp/random"
      version = "3.7.2"
    }
    time = {
      source  = "hashicorp/time"
      version = "0.13.1"
    }
  }

  backend "s3" {
    bucket                      = "tfstate"
    key                         = "home-cluster.tfstate"
    region                      = "main"
    skip_region_validation      = true
    skip_credentials_validation = true # Skip AWS related checks and validations
    skip_requesting_account_id  = true
    skip_metadata_api_check     = true
    use_path_style              = true
    endpoints = {
      s3 = "http://192.168.0.151:9000"
    }
  }

  required_version = "~> 1.12.0"
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
    kubectl    = kubectl
  }

  depends_on = [helm_release.nfs_provisioner]
}

module "apps" {
  source = "./apps/"

  postgres_apps_password = var.postgres_apps_password
  home_registry_password = var.home_registry_password
  penpot_api_key         = var.penpot_api_key

  providers = {
    kubernetes = kubernetes
    helm       = helm
    kubectl    = kubectl
    time       = time
  }

  depends_on = [module.networking, helm_release.nfs_provisioner]
}

module "monitoring" {
  source = "./monitoring/"


  domain                 = var.domain
  home_registry_password = var.home_registry_password
  grafana_password       = var.grafana_password

  providers = {
    kubernetes = kubernetes
    helm       = helm
    kubectl    = kubectl
  }
  depends_on = [helm_release.nfs_provisioner, module.networking]
}

