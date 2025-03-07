resource "kubernetes_secret" "redis_auth" {
  metadata {
    name      = "redis-auth"
    namespace = kubernetes_namespace.apps.metadata[0].name
  }

  data = {
    password = "assword"
  }
}


resource "helm_release" "redis" {
  name       = "redis"
  namespace  = kubernetes_namespace.apps.metadata[0].name
  chart      = "redis"
  repository = "oci://registry-1.docker.io/bitnamicharts/"
  version    = "20.6.3"
  values     = [file("${path.module}/values/redis-values.yaml")]
  depends_on = [kubernetes_namespace.apps, kubernetes_secret.redis_auth]
}


# https://github.com/RedisInsight/RedisInsight/issues/4019

# resource "kubernetes_ingress_v1" "redisinsight" {
#   metadata {
#     name      = "redisinsight"
#     namespace = kubernetes_namespace.apps.metadata[0].name
#     labels = {
#       app = "redisinsight"
#     }
#     annotations = {
#       "cert-manager.io/cluster-issuer" = "letsencrypt"
#     }
#   }
#
#   spec {
#     tls {
#       hosts       = ["redisinsight.stevevaradi.me"]
#       secret_name = "redisinsight-ingress-secret"
#     }
#
#     rule {
#       host = "redisinsight.stevevaradi.me"
#
#       http {
#         path {
#           path      = "/"
#           path_type = "Prefix"
#
#           backend {
#             service {
#               name = "redisinsight-service"
#               port {
#                 name = "http"
#               }
#             }
#           }
#         }
#       }
#     }
#   }
#
#   depends_on = [kubernetes_namespace.apps]
# }
#
# resource "kubernetes_service_v1" "redisinsight_service" {
#   metadata {
#     name      = "redisinsight-service"
#     namespace = kubernetes_namespace.apps.metadata[0].name
#     labels = {
#       app = "redisinsight"
#     }
#   }
#
#   spec {
#     type = "ClusterIP"
#
#     port {
#       port        = 80
#       target_port = 5540
#       protocol    = "TCP"
#       name        = "http"
#     }
#
#     selector = {
#       app = "redisinsight"
#     }
#   }
#
#   depends_on = [kubernetes_namespace.apps]
#
# }
#
# resource "kubernetes_persistent_volume_claim_v1" "redisinsight_pvc" {
#   metadata {
#     name      = "redisinsight-pvc"
#     namespace = kubernetes_namespace.apps.metadata[0].name
#     labels = {
#       app = "redisinsight"
#     }
#   }
#
#   spec {
#     access_modes = ["ReadWriteOnce"]
#     resources {
#       requests = {
#         storage = "4Gi"
#       }
#     }
#     storage_class_name = "nfs-csi"
#   }
#
#   depends_on = [kubernetes_namespace.apps]
# }
#
# resource "kubernetes_deployment_v1" "redisinsight" {
#   metadata {
#     name      = "redisinsight"
#     namespace = kubernetes_namespace.apps.metadata[0].name
#     labels = {
#       app = "redisinsight"
#     }
#   }
#
#   spec {
#     replicas = 1
#
#     selector {
#       match_labels = {
#         app = "redisinsight"
#       }
#     }
#
#     strategy {
#       type = "RollingUpdate"
#       rolling_update {
#         max_unavailable = 1
#         max_surge       = 0
#       }
#     }
#
#     template {
#       metadata {
#         labels = {
#           app = "redisinsight"
#         }
#       }
#
#       spec {
#
#         init_container {
#           name    = "init"
#           image   = "busybox"
#           command = ["/bin/sh", "-c", "chown -R 1000:1000 /data"]
#           volume_mount {
#             name       = "db"
#             mount_path = "/data"
#           }
#
#         }
#
#         container {
#           name  = "redisinsight"
#           image = "redis/redisinsight:2.62"
#
#           image_pull_policy = "IfNotPresent"
#
#           env {
#             name  = "SERVER_TLS"
#             value = "false"
#           }
#
#           volume_mount {
#             name       = "db"
#             mount_path = "/data"
#           }
#
#           port {
#             container_port = 5540
#             protocol       = "TCP"
#             name           = "http"
#           }
#
#           resources {
#             requests = {
#               cpu    = "50m"
#               memory = "256Mi"
#             }
#             limits = {
#               cpu    = "200m"
#               memory = "512Mi"
#             }
#           }
#
#           # liveness_probe {
#           #   http_get {
#           #     path = "/api/health"
#           #     port = "http"
#           #   }
#           #
#           #   initial_delay_seconds = 60
#           #   period_seconds        = 5
#           #   timeout_seconds       = 3
#           #   failure_threshold     = 3
#           # }
#         }
#         security_context {
#           fs_group = 1000
#         }
#
#         volume {
#           name = "db"
#           persistent_volume_claim {
#             claim_name = "redisinsight-pvc"
#           }
#         }
#
#       }
#     }
#   }
#
#   depends_on = [kubernetes_namespace.apps]
#
# }
