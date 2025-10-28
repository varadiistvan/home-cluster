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


resource "kubernetes_service_v1" "mainsail_external" {
  metadata {
    name      = "mainsail-external"
    namespace = kubernetes_namespace.external.id
  }
  spec {
    port {
      name        = "web"
      port        = 80
      target_port = 80
      protocol    = "TCP"
    }
    port {
      name        = "cam"
      port        = 8899
      target_port = 8899
      protocol    = "TCP"
    }
  }
}

resource "kubernetes_manifest" "mainsail_endpoint_slice" {
  manifest = {
    apiVersion = "discovery.k8s.io/v1"
    kind       = "EndpointSlice"
    metadata = {
      name      = "mainsail-external-1"
      namespace = kubernetes_namespace.external.id
      labels = {
        "kubernetes.io/service-name" = kubernetes_service_v1.mainsail_external.metadata[0].name
      }
    }
    addressType = "IPv4"
    ports = [
      {
        name     = "web"
        protocol = "TCP"
        port     = 80
      },
      {
        name     = "cam"
        protocol = "TCP"
        port     = 8899
      }
    ]
    endpoints = [
      {
        addresses  = ["192.168.0.160"]
        conditions = { ready = true }
      }
    ]
  }
}

resource "kubernetes_ingress_v1" "mainsail" {
  metadata {
    name      = "mainsail"
    namespace = kubernetes_namespace.external.id
    annotations = {
      "cert-manager.io/cluster-issuer" = "letsencrypt"

      "nginx.ingress.kubernetes.io/whitelist-source-range"  = "192.168.0.0/24,10.192.1.0/24"
      "nginx.ingress.kubernetes.io/proxy-body-size"         = "0"
      "nginx.ingress.kubernetes.io/proxy-read-timeout"      = "600"
      "nginx.ingress.kubernetes.io/proxy-send-timeout"      = "600"
      "nginx.ingress.kubernetes.io/proxy-request-buffering" = "off"
      "nginx.ingress.kubernetes.io/backend-protocol"        = "HTTP"
      "nginx.ingress.kubernetes.io/use-regex"               = "true"
    }
  }

  spec {
    ingress_class_name = "nginx"

    tls {
      hosts       = ["mainsail.stevevaradi.me"]
      secret_name = "mainsail-tls"
    }

    rule {
      host = "mainsail.stevevaradi.me"
      http {
        path {
          path      = "/"
          path_type = "Prefix"
          backend {
            service {
              name = kubernetes_service_v1.mainsail_external.metadata[0].name
              port {
                name = "web"
              }
            }
          }
        }
        path {
          path      = "/(stream)|(snapshot)"
          path_type = "ImplementationSpecific"
          backend {
            service {
              name = kubernetes_service_v1.mainsail_external.metadata[0].name
              port {
                name = "cam"
              }
            }
          }
        }
      }
    }
  }
}

resource "kubernetes_service_v1" "ollama_external" {
  metadata {
    name      = "ollama-external"
    namespace = kubernetes_namespace.external.id
  }
  spec {
    port {
      name        = "web"
      port        = 11434
      target_port = 11434
      protocol    = "TCP"
    }
  }
}

resource "kubernetes_manifest" "ollama_endpoint_slice" {
  manifest = {
    apiVersion = "discovery.k8s.io/v1"
    kind       = "EndpointSlice"
    metadata = {
      name      = "ollama-external-1"
      namespace = kubernetes_namespace.external.id
      labels = {
        "kubernetes.io/service-name" = kubernetes_service_v1.ollama_external.metadata[0].name
      }
    }
    addressType = "IPv4"
    ports = [
      {
        name     = "web"
        protocol = "TCP"
        port     = 11434
      },
    ]
    endpoints = [
      {
        addresses  = ["192.168.0.145"]
        conditions = { ready = true }
      }
    ]
  }
}

resource "kubernetes_ingress_v1" "ollama" {
  metadata {
    name      = "ollama"
    namespace = kubernetes_namespace.external.id
    annotations = {
      "cert-manager.io/cluster-issuer" = "letsencrypt"

      "nginx.ingress.kubernetes.io/whitelist-source-range"  = "192.168.0.0/24,10.192.1.0/24"
      "nginx.ingress.kubernetes.io/proxy-body-size"         = "0"
      "nginx.ingress.kubernetes.io/proxy-read-timeout"      = "600"
      "nginx.ingress.kubernetes.io/proxy-send-timeout"      = "600"
      "nginx.ingress.kubernetes.io/proxy-request-buffering" = "off"
      "nginx.ingress.kubernetes.io/backend-protocol"        = "HTTP"
      "nginx.ingress.kubernetes.io/use-regex"               = "true"
    }
  }

  spec {
    ingress_class_name = "nginx"

    tls {
      hosts       = ["ollama.stevevaradi.me"]
      secret_name = "ollama-tls"
    }

    rule {
      host = "ollama.stevevaradi.me"
      http {
        path {
          path      = "/"
          path_type = "Prefix"
          backend {
            service {
              name = kubernetes_service_v1.ollama_external.metadata[0].name
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



resource "kubernetes_service_v1" "nas_external" {
  metadata {
    name      = "nas-external"
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

resource "kubernetes_manifest" "nas_endpoint_slice" {
  manifest = {
    apiVersion = "discovery.k8s.io/v1"
    kind       = "EndpointSlice"
    metadata = {
      name      = "nas-external-1"
      namespace = kubernetes_namespace.external.id
      labels = {
        "kubernetes.io/service-name" = kubernetes_service_v1.nas_external.metadata[0].name
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
        addresses  = ["192.168.0.151"]
        conditions = { ready = true }
      }
    ]
  }
}

resource "kubernetes_ingress_v1" "nas" {
  metadata {
    name      = "nas"
    namespace = kubernetes_namespace.external.id
    annotations = {
      "cert-manager.io/cluster-issuer" = "letsencrypt"

      "nginx.ingress.kubernetes.io/whitelist-source-range"  = "192.168.0.0/24,10.192.1.0/24"
      "nginx.ingress.kubernetes.io/proxy-body-size"         = "0"
      "nginx.ingress.kubernetes.io/proxy-read-timeout"      = "600"
      "nginx.ingress.kubernetes.io/proxy-send-timeout"      = "600"
      "nginx.ingress.kubernetes.io/proxy-request-buffering" = "off"
      "nginx.ingress.kubernetes.io/backend-protocol"        = "HTTP"
      "nginx.ingress.kubernetes.io/use-regex"               = "true"
    }
  }

  spec {
    ingress_class_name = "nginx"

    tls {
      hosts       = ["nas.stevevaradi.me"]
      secret_name = "nas-tls"
    }

    rule {
      host = "nas.stevevaradi.me"
      http {
        path {
          path      = "/"
          path_type = "Prefix"
          backend {
            service {
              name = kubernetes_service_v1.nas_external.metadata[0].name
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
