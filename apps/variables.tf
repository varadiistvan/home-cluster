variable "postgres_apps_password" {
  type      = string
  sensitive = true
}

variable "home_registry_password" {
  type      = string
  sensitive = true
}

variable "penpot_api_key" {
  type      = string
  sensitive = true
}

variable "renovate_minio_secret" {
  type      = string
  sensitive = true
}

variable "renovate_minio_key" {
  type      = string
  sensitive = true
}

variable "renovate_token" {
  type      = string
  sensitive = true
}

variable "renovate_github_token" {
  type      = string
  sensitive = true
}

variable "copyparty_password" {
  type      = string
  sensitive = true
}

variable "geeki_master" {
  type      = string
  sensitive = true
}

variable "gmail_app_pass" {
  type      = string
  sensitive = false
}
