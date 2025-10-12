locals {
  unifi_ip = "192.168.0.153"
}

resource "kubectl_manifest" "unifi_ip_pool" {
  yaml_body = <<-YAML
    apiVersion: cilium.io/v2
    kind: CiliumLoadBalancerIPPool
    metadata:
      name: vip-unifi
    spec:
      blocks:
        - start: ${local.unifi_ip}
          stop:  ${local.unifi_ip}
  YAML
}

resource "random_password" "unifi_mongodb_password" {
  length  = 16
  special = false
}

resource "kubernetes_secret" "unifi_mongodb_secret" {
  metadata {
    name      = "unifi-mongodb"
    namespace = kubernetes_namespace.apps.id
  }
  data = {
    password = random_password.unifi_mongodb_password.result
  }
}


resource "kubectl_manifest" "unifi_mongodb" {
  yaml_body = <<-YAML
  apiVersion: mongodbcommunity.mongodb.com/v1
  kind: MongoDBCommunity
  metadata:
    name: unifi-mongodb
    namespace: ${kubernetes_namespace.apps.id}
  spec:
    members: 1
    type: ReplicaSet
    featureCompatibilityVersion: "7.0"
    version: "7.0.23-ubi9"
    security:
      authentication:
        modes: ["SCRAM"]
    users:
      - name: unifi
        db: admin
        passwordSecretRef: 
          name: ${kubernetes_secret.unifi_mongodb_secret.metadata[0].name}
        roles:
          - name: clusterAdmin
            db: admin
          - name: userAdminAnyDatabase
            db: admin
        scramCredentialsSecretName: unifi-scram
    additionalMongodConfig:
      storage.wiredTiger.engineConfig.journalCompressor: zlib
  YAML

  depends_on = [helm_release.mongodb_community_operator]
}

resource "helm_release" "unifi" {
  name       = "unifi"
  namespace  = kubernetes_namespace.apps.id
  chart      = "unifi"
  version    = "1.14.0"
  repository = "oci://ghcr.io/mkilchhofer/unifi-chart"
  values     = [file("${path.module}/values/unifi-values.yaml")]
  timeout    = 600
  depends_on = [kubernetes_namespace.apps]

  set = [{
    name  = "unifiedService.loadBalancerIP"
    value = local.unifi_ip
  }]

  # set_list = [{
  #   name  = "unifiedService.loadBalancerSourceRanges"
  #   value = []
  # }]

  lifecycle {
    ignore_changes = [metadata]
  }
}
