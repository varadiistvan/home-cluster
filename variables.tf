variable "client_certificate" {
  type      = string
  sensitive = true
}

variable "client_key" {
  type      = string
  sensitive = true
}

variable "kubernetes_host" {
  type        = string
  description = "The Kubernetes API server endpoint."
  default     = "https://192.168.0.151:6443"
}

variable "cluster_ca_certificate" {
  type      = string
  sensitive = true
}

variable "cloudflare_api_key" {
  type      = string
  sensitive = true
}

variable "domain" {
  type    = string
  default = "stevevaradi.me"
}

variable "postgres_apps_password" {
  type      = string
  sensitive = true
  default   = null
}

variable "home_registry_password" {
  type      = string
  sensitive = true
}

variable "grafana_password" {
  type      = string
  sensitive = true
}

variable "penpot_api_key" {
  type      = string
  sensitive = true
}

variable "iscsi_provisioner_token" {
  type      = string
  sensitive = true
}
