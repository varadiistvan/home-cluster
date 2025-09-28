
resource "random_password" "ha_pass" {
  length  = 24
  special = false
}

resource "random_password" "z2m_pass" {
  length  = 24
  special = false
}

resource "random_password" "findmy_pass" {
  length  = 24
  special = false
}

resource "kubernetes_secret" "mqtt_users" {
  metadata {
    name      = "mqtt-users"
    namespace = kubernetes_namespace.apps.id
  }

  data = {
    DOCKER_VERNEMQ_USER_homeassistant : random_password.ha_pass.result
    DOCKER_VERNEMQ_USER_zigbee2mqtt : random_password.z2m_pass.result
    DOCKER_VERNEMQ_USER_findmy : random_password.findmy_pass.result
    "secret.yaml" : <<-YAML
      password: ${random_password.z2m_pass.result}
    YAML
  }
}

resource "kubectl_manifest" "mqqt_cert" {
  yaml_body = <<-YAML
    apiVersion: cert-manager.io/v1
    kind: Certificate
    metadata:
      name: mqtt-cert
      namespace: ${kubernetes_namespace.apps.id}
    spec:
      secretName: mqtt-tls
      issuerRef:
        kind: ClusterIssuer
        name: letsencrypt
      commonName: mqtt.stevevaradi.me
      dnsNames:
        - mqtt.stevevaradi.me
  YAML
}

resource "helm_release" "vernemq" {
  name       = "vernemq"
  namespace  = kubernetes_namespace.apps.id
  chart      = "vernemq"
  repository = "https://vernemq.github.io/docker-vernemq"
  version    = "2.1.1"
  values     = [file("${path.module}/values/vernemq-values.yaml")]

  set = [{
    name  = "secretMounts[0].secretName"
    value = "mqtt-tls"
  }]

  timeout = 600

  lifecycle {
    ignore_changes = [metadata]
  }
}


resource "helm_release" "z2m" {
  name       = "z2m"
  namespace  = kubernetes_namespace.apps.id
  chart      = "zigbee2mqtt"
  repository = "https://charts.zigbee2mqtt.io/"
  version    = "2.6.1"

  values = [file("${path.module}/values/z2m-values.yaml")]

  set = [
    {
      name  = "statefulset.secrets.name"
      value = kubernetes_secret.mqtt_users.metadata[0].name
    },
    {
      name  = "zigbee2mqtt.mqtt.password"
      value = "!secret.yaml password"
    }
  ]

  lifecycle {
    ignore_changes = [metadata]
  }
}

resource "kubernetes_ingress_v1" "z2m_frontend" {
  metadata {
    name      = "z2m-frontend"
    namespace = kubernetes_namespace.apps.id
    annotations = {
      "cert-manager.io/cluster-issuer"                     = "letsencrypt"
      "nginx.ingress.kubernetes.io/whitelist-source-range" = "192.168.0.1/24, 10.192.1.1/24"
    }
  }
  spec {
    tls {
      hosts       = ["z2m.stevevaradi.me"]
      secret_name = "z2m-tls"
    }
    rule {
      host = "z2m.stevevaradi.me"
      http {
        path {
          path      = "/"
          path_type = "ImplementationSpecific"
          backend {
            service {
              name = "z2m-zigbee2mqtt"
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
