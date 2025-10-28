resource "kubernetes_secret_v1" "renovate_secret" {
  metadata {
    name      = "renovate-env"
    namespace = kubernetes_namespace.apps.id
  }

  data = {
    RENOVATE_TOKEN   = var.renovate_token
    GITHUB_COM_TOKEN = var.renovate_github_token

    RENOVATE_REDIS_URL    = "redis://:${random_password.redis_passwords["renovate"].result}@${helm_release.redis["renovate"].name}-master:6379/0"
    RENOVATE_REDIS_PREFIX = "renovate:"

    RENOVATE_REPOSITORY_CACHE      = "enabled"
    RENOVATE_REPOSITORY_CACHE_TYPE = "s3://renovate"
    RENOVATE_S3_ENDPOINT           = "https://api.minio.stevevaradi.me"
    RENOVATE_S3_PATH_STYLE         = "true"
    RENOVATE_S3_ACCESS_KEY_ID      = var.renovate_minio_key
    RENOVATE_S3_SECRET_ACCESS_KEY  = var.renovate_minio_secret
    AWS_ACCESS_KEY_ID              = var.renovate_minio_key
    AWS_SECRET_ACCESS_KEY          = var.renovate_minio_secret
    AWS_EC2_METADATA_DISABLED      = "true"
    AWS_REGION                     = "main"

    RENOVATE_DETECT_HOST_RULES_FROM_ENV = "true"
    RENOVATE_HOST_RULES_1_MATCHHOST     = "harbor.stevevaradi.me"
    RENOVATE_HOST_RULES_1_HOSTTYPE      = "docker"
    RENOVATE_HOST_RULES_1_USERNAME      = "stevev"
    RENOVATE_HOST_RULES_1_PASSWORD      = var.home_registry_password

    RENOVATE_HOST_RULES_2_MATCHHOST = "harbor.stevevaradi.me"
    RENOVATE_HOST_RULES_2_HOSTTYPE  = "helm"
    RENOVATE_HOST_RULES_2_USERNAME  = "stevev"
    RENOVATE_HOST_RULES_2_PASSWORD  = var.home_registry_password

  }

}

resource "helm_release" "renovate" {
  name       = "renovate"
  namespace  = kubernetes_namespace.apps.id
  repository = "oci://ghcr.io/renovatebot/charts"
  chart      = "renovate"
  version    = "44.15.1"

  values = [file("${path.module}/values/renovate-values.yaml")]

  depends_on = [
    helm_release.redis["renovate"],
    kubernetes_secret_v1.renovate_secret
  ]

  lifecycle {
    ignore_changes = [metadata]
  }
}

