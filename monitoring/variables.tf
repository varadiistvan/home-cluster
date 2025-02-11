variable "domain" {
  type = string
}

variable "home_registry_password" {
  type      = string
  sensitive = true
}
