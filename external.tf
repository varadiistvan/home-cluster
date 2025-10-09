resource "kubernetes_namespace" "external" {
  metadata {
    name = "external"
  }
}

resource "kubernetes_service_v1" "minio_external" {
  metadata {
    name      = "minio-external"
    namespace = kubernetes_namespace.external.id
  }
  spec {
    port {
      name        = "web"
      port        = 9001
      target_port = 9001
      protocol    = "TCP"
    }
    port {
      name        = "s3"
      port        = 9000
      target_port = 9000
      protocol    = "TCP"
    }
  }
}

resource "kubernetes_manifest" "minio_endpoint_slice" {
  manifest = {
    apiVersion = "discovery.k8s.io/v1"
    kind       = "EndpointSlice"
    metadata = {
      name      = "minio-external-1"
      namespace = kubernetes_namespace.external.id
      labels = {
        "kubernetes.io/service-name" = kubernetes_service_v1.minio_external.metadata[0].name
      }
    }
    addressType = "IPv4"
    ports = [
      {
        name     = "web"
        protocol = "TCP"
        port     = 9001
      },
      {
        name     = "s3"
        protocol = "TCP"
        port     = 9000
      }

    ]
    endpoints = [
      {
        addresses  = ["192.168.0.151"]
        conditions = { ready = true }
      }
    ]
  }
}

resource "kubernetes_ingress_v1" "minio" {
  metadata {
    name      = "minio"
    namespace = kubernetes_namespace.external.id
    annotations = {
      # cert-manager
      "cert-manager.io/cluster-issuer" = "letsencrypt"

      # NGINX Ingress Controller
      "nginx.ingress.kubernetes.io/whitelist-source-range"  = "192.168.0.0/24,10.192.1.0/24"
      "nginx.ingress.kubernetes.io/proxy-body-size"         = "0" # unlimited uploads
      "nginx.ingress.kubernetes.io/proxy-read-timeout"      = "600"
      "nginx.ingress.kubernetes.io/proxy-send-timeout"      = "600"
      "nginx.ingress.kubernetes.io/proxy-request-buffering" = "off" # stream large uploads
      "nginx.ingress.kubernetes.io/backend-protocol"        = "HTTP"
    }
  }

  spec {
    ingress_class_name = "nginx"

    tls {
      hosts       = ["minio.stevevaradi.me", "api.minio.stevevaradi.me"]
      secret_name = "minio-tls"
    }

    rule {
      host = "minio.stevevaradi.me"
      http {
        path {
          path      = "/"
          path_type = "Prefix"
          backend {
            service {
              name = kubernetes_service_v1.minio_external.metadata[0].name
              port {
                name = "web"
              }
            }
          }
        }
      }
    }
    rule {
      host = "api.minio.stevevaradi.me"
      http {
        path {
          path      = "/"
          path_type = "Prefix"
          backend {
            service {
              name = kubernetes_service_v1.minio_external.metadata[0].name
              port {
                name = "s3"
              }
            }
          }
        }
      }
    }

  }
}


resource "kubernetes_service_v1" "octoprint_external" {
  metadata {
    name      = "octoprint-external"
    namespace = kubernetes_namespace.external.id
  }
  spec {
    port {
      name        = "web"
      port        = 80
      target_port = 80
      protocol    = "TCP"
    }
  }
}

resource "kubernetes_manifest" "octoprint_endpoint_slice" {
  manifest = {
    apiVersion = "discovery.k8s.io/v1"
    kind       = "EndpointSlice"
    metadata = {
      name      = "octoprint-external-1"
      namespace = kubernetes_namespace.external.id
      labels = {
        "kubernetes.io/service-name" = kubernetes_service_v1.octoprint_external.metadata[0].name
      }
    }
    addressType = "IPv4"
    ports = [
      {
        name     = "web"
        protocol = "TCP"
        port     = 80
      },
    ]
    endpoints = [
      {
        addresses  = ["192.168.0.160"]
        conditions = { ready = true }
      }
    ]
  }
}

resource "kubernetes_ingress_v1" "octoprint" {
  metadata {
    name      = "octoprint"
    namespace = kubernetes_namespace.external.id
    annotations = {
      "cert-manager.io/cluster-issuer" = "letsencrypt"

      "nginx.ingress.kubernetes.io/whitelist-source-range"  = "192.168.0.0/24,10.192.1.0/24"
      "nginx.ingress.kubernetes.io/proxy-body-size"         = "0"
      "nginx.ingress.kubernetes.io/proxy-read-timeout"      = "600"
      "nginx.ingress.kubernetes.io/proxy-send-timeout"      = "600"
      "nginx.ingress.kubernetes.io/proxy-request-buffering" = "off"
      "nginx.ingress.kubernetes.io/backend-protocol"        = "HTTP"
    }
  }

  spec {
    ingress_class_name = "nginx"

    tls {
      hosts       = ["octoprint.stevevaradi.me"]
      secret_name = "octoprint-tls"
    }

    rule {
      host = "octoprint.stevevaradi.me"
      http {
        path {
          path      = "/"
          path_type = "Prefix"
          backend {
            service {
              name = kubernetes_service_v1.octoprint_external.metadata[0].name
              port {
                name = "web"
              }
            }
          }
        }
      }
    }
  }
}
