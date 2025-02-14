variable "domain" {
  type = string
}

variable "home_registry_password" {
  type      = string
  sensitive = true
}

variable "grafana_password" {
  type      = string
  sensitive = true
}
