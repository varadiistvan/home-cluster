resource "kubernetes_namespace" "upgrade_controller" {
  metadata {
    name = "system-upgrade"
  }
}

resource "kubernetes_service_account" "upgrade_controller" {
  metadata {
    name      = "system-upgrade"
    namespace = kubernetes_namespace.upgrade_controller.id
  }

  # secret {
  #   name = kubernetes_secret_v1.upgrade_controller.id
  # }
}

# resource "kubernetes_secret_v1" "upgrade_controller" {
#   metadata {
#     name      = "system-upgrade-token"
#     namespace = kubernetes_namespace.upgrade_controller.id
#     annotations = {
#       "kubernetes.io/service-account.name" = kubernetes_namespace.upgrade_controller.id
#     }
#   }
#
#   type = "kubernetes.io/service-account-token"
# }

resource "kubernetes_cluster_role_binding" "upgrade_controller" {
  metadata {
    name = "system-upgrade"
  }

  role_ref {
    api_group = "rbac.authorization.k8s.io"
    kind      = "ClusterRole"
    name      = "cluster-admin"
  }

  subject {
    kind      = "ServiceAccount"
    name      = "system-upgrade"
    namespace = kubernetes_namespace.upgrade_controller.id
  }
}

resource "kubernetes_config_map" "upgrade_controller" {
  metadata {
    name      = "default-controller-env"
    namespace = kubernetes_namespace.upgrade_controller.id
  }

  data = {
    SYSTEM_UPGRADE_CONTROLLER_DEBUG             = "false"
    SYSTEM_UPGRADE_CONTROLLER_THREADS           = "2"
    SYSTEM_UPGRADE_JOB_ACTIVE_DEADLINE_SECONDS  = "900"
    SYSTEM_UPGRADE_JOB_BACKOFF_LIMIT            = "99"
    SYSTEM_UPGRADE_JOB_IMAGE_PULL_POLICY        = "IfNotPresent"
    SYSTEM_UPGRADE_JOB_KUBECTL_IMAGE            = "rancher/kubectl:v1.31.9"
    SYSTEM_UPGRADE_JOB_PRIVILEGED               = "true"
    SYSTEM_UPGRADE_JOB_TTL_SECONDS_AFTER_FINISH = "900"
    SYSTEM_UPGRADE_PLAN_POLLING_INTERVAL        = "15m"
  }
}

resource "kubectl_manifest" "upgrade_crds" {
  yaml_body = <<YAML
    apiVersion: apiextensions.k8s.io/v1
    kind: CustomResourceDefinition
    metadata:
      name: plans.upgrade.cattle.io
    spec:
      group: upgrade.cattle.io
      names:
        categories:
        - upgrade
        kind: Plan
        plural: plans
        singular: plan
      preserveUnknownFields: false
      scope: Namespaced
      versions:
      - additionalPrinterColumns:
        - jsonPath: .spec.upgrade.image
          name: Image
          type: string
        - jsonPath: .spec.channel
          name: Channel
          type: string
        - jsonPath: .spec.version
          name: Version
          type: string
        name: v1
        schema:
          openAPIV3Schema:
            properties:
              spec:
                properties:
                  channel:
                    nullable: true
                    type: string
                  concurrency:
                    type: integer
                  cordon:
                    type: boolean
                  drain:
                    nullable: true
                    properties:
                      deleteEmptydirData:
                        nullable: true
                        type: boolean
                      deleteLocalData:
                        nullable: true
                        type: boolean
                      disableEviction:
                        type: boolean
                      force:
                        type: boolean
                      gracePeriod:
                        nullable: true
                        type: integer
                      ignoreDaemonSets:
                        nullable: true
                        type: boolean
                      podSelector:
                        nullable: true
                        properties:
                          matchExpressions:
                            items:
                              properties:
                                key:
                                  nullable: true
                                  type: string
                                operator:
                                  nullable: true
                                  type: string
                                values:
                                  items:
                                    nullable: true
                                    type: string
                                  nullable: true
                                  type: array
                              type: object
                            nullable: true
                            type: array
                          matchLabels:
                            additionalProperties:
                              nullable: true
                              type: string
                            nullable: true
                            type: object
                        type: object
                      skipWaitForDeleteTimeout:
                        type: integer
                      timeout:
                        nullable: true
                        type: integer
                    type: object
                  exclusive:
                    type: boolean
                  imagePullSecrets:
                    items:
                      properties:
                        name:
                          nullable: true
                          type: string
                      type: object
                    nullable: true
                    type: array
                  jobActiveDeadlineSecs:
                    type: integer
                  nodeSelector:
                    nullable: true
                    properties:
                      matchExpressions:
                        items:
                          properties:
                            key:
                              nullable: true
                              type: string
                            operator:
                              nullable: true
                              type: string
                            values:
                              items:
                                nullable: true
                                type: string
                              nullable: true
                              type: array
                          type: object
                        nullable: true
                        type: array
                      matchLabels:
                        additionalProperties:
                          nullable: true
                          type: string
                        nullable: true
                        type: object
                    type: object
                  postCompleteDelay:
                    nullable: true
                    type: string
                  prepare:
                    nullable: true
                    properties:
                      args:
                        items:
                          nullable: true
                          type: string
                        nullable: true
                        type: array
                      command:
                        items:
                          nullable: true
                          type: string
                        nullable: true
                        type: array
                      envFrom:
                        items:
                          properties:
                            configMapRef:
                              nullable: true
                              properties:
                                name:
                                  nullable: true
                                  type: string
                                optional:
                                  nullable: true
                                  type: boolean
                              type: object
                            prefix:
                              nullable: true
                              type: string
                            secretRef:
                              nullable: true
                              properties:
                                name:
                                  nullable: true
                                  type: string
                                optional:
                                  nullable: true
                                  type: boolean
                              type: object
                          type: object
                        nullable: true
                        type: array
                      envs:
                        items:
                          properties:
                            name:
                              nullable: true
                              type: string
                            value:
                              nullable: true
                              type: string
                            valueFrom:
                              nullable: true
                              properties:
                                configMapKeyRef:
                                  nullable: true
                                  properties:
                                    key:
                                      nullable: true
                                      type: string
                                    name:
                                      nullable: true
                                      type: string
                                    optional:
                                      nullable: true
                                      type: boolean
                                  type: object
                                fieldRef:
                                  nullable: true
                                  properties:
                                    apiVersion:
                                      nullable: true
                                      type: string
                                    fieldPath:
                                      nullable: true
                                      type: string
                                  type: object
                                resourceFieldRef:
                                  nullable: true
                                  properties:
                                    containerName:
                                      nullable: true
                                      type: string
                                    divisor:
                                      nullable: true
                                      type: string
                                    resource:
                                      nullable: true
                                      type: string
                                  type: object
                                secretKeyRef:
                                  nullable: true
                                  properties:
                                    key:
                                      nullable: true
                                      type: string
                                    name:
                                      nullable: true
                                      type: string
                                    optional:
                                      nullable: true
                                      type: boolean
                                  type: object
                              type: object
                          type: object
                        nullable: true
                        type: array
                      image:
                        nullable: true
                        type: string
                      securityContext:
                        nullable: true
                        properties:
                          allowPrivilegeEscalation:
                            nullable: true
                            type: boolean
                          appArmorProfile:
                            nullable: true
                            properties:
                              localhostProfile:
                                nullable: true
                                type: string
                              type:
                                nullable: true
                                type: string
                            type: object
                          capabilities:
                            nullable: true
                            properties:
                              add:
                                items:
                                  nullable: true
                                  type: string
                                nullable: true
                                type: array
                              drop:
                                items:
                                  nullable: true
                                  type: string
                                nullable: true
                                type: array
                            type: object
                          privileged:
                            nullable: true
                            type: boolean
                          procMount:
                            nullable: true
                            type: string
                          readOnlyRootFilesystem:
                            nullable: true
                            type: boolean
                          runAsGroup:
                            nullable: true
                            type: integer
                          runAsNonRoot:
                            nullable: true
                            type: boolean
                          runAsUser:
                            nullable: true
                            type: integer
                          seLinuxOptions:
                            nullable: true
                            properties:
                              level:
                                nullable: true
                                type: string
                              role:
                                nullable: true
                                type: string
                              type:
                                nullable: true
                                type: string
                              user:
                                nullable: true
                                type: string
                            type: object
                          seccompProfile:
                            nullable: true
                            properties:
                              localhostProfile:
                                nullable: true
                                type: string
                              type:
                                nullable: true
                                type: string
                            type: object
                          windowsOptions:
                            nullable: true
                            properties:
                              gmsaCredentialSpec:
                                nullable: true
                                type: string
                              gmsaCredentialSpecName:
                                nullable: true
                                type: string
                              hostProcess:
                                nullable: true
                                type: boolean
                              runAsUserName:
                                nullable: true
                                type: string
                            type: object
                        type: object
                      volumes:
                        items:
                          properties:
                            destination:
                              nullable: true
                              type: string
                            name:
                              nullable: true
                              type: string
                            source:
                              nullable: true
                              type: string
                          type: object
                        nullable: true
                        type: array
                    type: object
                  secrets:
                    items:
                      properties:
                        ignoreUpdates:
                          type: boolean
                        name:
                          nullable: true
                          type: string
                        path:
                          nullable: true
                          type: string
                      type: object
                    nullable: true
                    type: array
                  serviceAccountName:
                    nullable: true
                    type: string
                  tolerations:
                    items:
                      properties:
                        effect:
                          nullable: true
                          type: string
                        key:
                          nullable: true
                          type: string
                        operator:
                          nullable: true
                          type: string
                        tolerationSeconds:
                          nullable: true
                          type: integer
                        value:
                          nullable: true
                          type: string
                      type: object
                    nullable: true
                    type: array
                  upgrade:
                    nullable: true
                    properties:
                      args:
                        items:
                          nullable: true
                          type: string
                        nullable: true
                        type: array
                      command:
                        items:
                          nullable: true
                          type: string
                        nullable: true
                        type: array
                      envFrom:
                        items:
                          properties:
                            configMapRef:
                              nullable: true
                              properties:
                                name:
                                  nullable: true
                                  type: string
                                optional:
                                  nullable: true
                                  type: boolean
                              type: object
                            prefix:
                              nullable: true
                              type: string
                            secretRef:
                              nullable: true
                              properties:
                                name:
                                  nullable: true
                                  type: string
                                optional:
                                  nullable: true
                                  type: boolean
                              type: object
                          type: object
                        nullable: true
                        type: array
                      envs:
                        items:
                          properties:
                            name:
                              nullable: true
                              type: string
                            value:
                              nullable: true
                              type: string
                            valueFrom:
                              nullable: true
                              properties:
                                configMapKeyRef:
                                  nullable: true
                                  properties:
                                    key:
                                      nullable: true
                                      type: string
                                    name:
                                      nullable: true
                                      type: string
                                    optional:
                                      nullable: true
                                      type: boolean
                                  type: object
                                fieldRef:
                                  nullable: true
                                  properties:
                                    apiVersion:
                                      nullable: true
                                      type: string
                                    fieldPath:
                                      nullable: true
                                      type: string
                                  type: object
                                resourceFieldRef:
                                  nullable: true
                                  properties:
                                    containerName:
                                      nullable: true
                                      type: string
                                    divisor:
                                      nullable: true
                                      type: string
                                    resource:
                                      nullable: true
                                      type: string
                                  type: object
                                secretKeyRef:
                                  nullable: true
                                  properties:
                                    key:
                                      nullable: true
                                      type: string
                                    name:
                                      nullable: true
                                      type: string
                                    optional:
                                      nullable: true
                                      type: boolean
                                  type: object
                              type: object
                          type: object
                        nullable: true
                        type: array
                      image:
                        nullable: true
                        type: string
                      securityContext:
                        nullable: true
                        properties:
                          allowPrivilegeEscalation:
                            nullable: true
                            type: boolean
                          appArmorProfile:
                            nullable: true
                            properties:
                              localhostProfile:
                                nullable: true
                                type: string
                              type:
                                nullable: true
                                type: string
                            type: object
                          capabilities:
                            nullable: true
                            properties:
                              add:
                                items:
                                  nullable: true
                                  type: string
                                nullable: true
                                type: array
                              drop:
                                items:
                                  nullable: true
                                  type: string
                                nullable: true
                                type: array
                            type: object
                          privileged:
                            nullable: true
                            type: boolean
                          procMount:
                            nullable: true
                            type: string
                          readOnlyRootFilesystem:
                            nullable: true
                            type: boolean
                          runAsGroup:
                            nullable: true
                            type: integer
                          runAsNonRoot:
                            nullable: true
                            type: boolean
                          runAsUser:
                            nullable: true
                            type: integer
                          seLinuxOptions:
                            nullable: true
                            properties:
                              level:
                                nullable: true
                                type: string
                              role:
                                nullable: true
                                type: string
                              type:
                                nullable: true
                                type: string
                              user:
                                nullable: true
                                type: string
                            type: object
                          seccompProfile:
                            nullable: true
                            properties:
                              localhostProfile:
                                nullable: true
                                type: string
                              type:
                                nullable: true
                                type: string
                            type: object
                          windowsOptions:
                            nullable: true
                            properties:
                              gmsaCredentialSpec:
                                nullable: true
                                type: string
                              gmsaCredentialSpecName:
                                nullable: true
                                type: string
                              hostProcess:
                                nullable: true
                                type: boolean
                              runAsUserName:
                                nullable: true
                                type: string
                            type: object
                        type: object
                      volumes:
                        items:
                          properties:
                            destination:
                              nullable: true
                              type: string
                            name:
                              nullable: true
                              type: string
                            source:
                              nullable: true
                              type: string
                          type: object
                        nullable: true
                        type: array
                    type: object
                  version:
                    nullable: true
                    type: string
                  window:
                    nullable: true
                    properties:
                      days:
                        items:
                          nullable: true
                          type: string
                        nullable: true
                        type: array
                      endTime:
                        nullable: true
                        type: string
                      startTime:
                        nullable: true
                        type: string
                      timeZone:
                        nullable: true
                        type: string
                    type: object
                required:
                - upgrade
                type: object
              status:
                properties:
                  applying:
                    items:
                      nullable: true
                      type: string
                    nullable: true
                    type: array
                  conditions:
                    items:
                      properties:
                        lastTransitionTime:
                          nullable: true
                          type: string
                        lastUpdateTime:
                          nullable: true
                          type: string
                        message:
                          nullable: true
                          type: string
                        reason:
                          nullable: true
                          type: string
                        status:
                          nullable: true
                          type: string
                        type:
                          nullable: true
                          type: string
                      type: object
                    nullable: true
                    type: array
                  latestHash:
                    nullable: true
                    type: string
                  latestVersion:
                    nullable: true
                    type: string
                type: object
            type: object
        served: true
        storage: true
        subresources:
          status: {}
  YAML
}

resource "kubernetes_deployment" "upgrade_controller" {
  metadata {
    name      = "system-upgrade-controller"
    namespace = kubernetes_namespace.upgrade_controller.metadata[0].name
  }

  spec {
    selector {
      match_labels = {
        "upgrade.cattle.io/controller" = "system-upgrade-controller"
      }
    }
    template {
      metadata {
        labels = {
          "upgrade.cattle.io/controller" = "system-upgrade-controller"
        }
      }

      spec {
        affinity {
          node_affinity {
            required_during_scheduling_ignored_during_execution {
              node_selector_term {
                match_expressions {
                  key      = "node-role.kubernetes.io/master"
                  operator = "In"
                  values   = ["true"]
                }
              }
            }
          }
        }

        container {
          image             = "rancher/system-upgrade-controller:v0.16.3"
          image_pull_policy = "Always"
          name              = "system-upgrade-controller"

          resources {
            requests = {
              cpu    = "1.0"
              memory = "500Mi"
            }
          }

          env {
            name = "SYSTEM_UPGRADE_CONTROLLER_NAME"
            value_from {
              field_ref {
                field_path = "metadata.labels['upgrade.cattle.io/controller']"
              }
            }
          }
          env {
            name = "SYSTEM_UPGRADE_CONTROLLER_NAMESPACE"
            value_from {
              field_ref {
                field_path = "metadata.namespace"
              }
            }
          }
          env_from {
            config_map_ref {
              name = "default-controller-env"
            }
          }

          volume_mount {
            mount_path = "/etc/ssl"
            name       = "etc-ssl"
          }

          volume_mount {
            mount_path = "tmp"
            name       = "tmp"
          }

          volume_mount {
            mount_path = "/etc/pki"
            name       = "etc-pki"
          }

          volume_mount {
            mount_path = "/etc/ca-certificates"
            name       = "etc-ca-certificates"
          }
        }

        service_account_name = kubernetes_service_account.upgrade_controller.metadata[0].name

        toleration {
          key      = "CriticalAddonsOnly"
          operator = "Exists"
        }
        toleration {
          effect   = "NoSchedule"
          key      = "node-role.kubernetes.io/master"
          operator = "Exists"
        }
        toleration {
          effect   = "NoSchedule"
          key      = "node-role.kubernetes.io/controlplane"
          operator = "Exists"
        }
        toleration {
          effect   = "NoSchedule"
          key      = "node-role.kubernetes.io/control-plane"
          operator = "Exists"
        }
        toleration {
          effect   = "NoSchedule"
          key      = "node-role.kubernetes.io/etcd"
          operator = "Exists"
        }
        volume {
          name = "etc-ssl"
          host_path {
            path = "/etc/ssl"
            type = "Directory"
          }
        }
        volume {
          name = "tmp"
          empty_dir {}
        }
        volume {
          name = "etc-pki"
          host_path {
            path = "/etc/pki"
            type = "DirectoryOrCreate"
          }
        }
        volume {
          name = "etc-ca-certificates"
          host_path {
            path = "/etc/ca-certificates"
            type = "DirectoryOrCreate"
          }
        }
      }
    }
  }
}



resource "kubectl_manifest" "client_plan" {
  yaml_body = <<YAML
    apiVersion: upgrade.cattle.io/v1
    kind: Plan
    metadata:
      name: client-upgrade-plan
      namespace: system-upgrade
      labels:
        k3s-upgrade: client
    spec:
      channel: https://update.k3s.io/v1-release/channels/stable
      serviceAccountName: system-upgrade
      concurrency: 1
      cordon: true
      drain:
        force: true
        deleteLocalData: true
        ignoreDaemonSets: true
      upgrade:
        image: rancher/k3s-upgrade
      nodeSelector:
        matchExpressions:
          - key: k3s-upgrade
            operator: Exists
          - key: k3s-upgrade
            operator: NotIn
            values:
              - disabled
              - "false"
          - key: node-role.kubernetes.io/control-plane
            operator: DoesNotExist
      prepare:
        image: rancher/k3s-upgrade
        args:
          - prepare
          - ${local.system_upgrade_name}
  YAML

  depends_on = [
    kubernetes_deployment.upgrade_controller,
    kubernetes_service_account.upgrade_controller,
    # kubernetes_secret_v1.upgrade_controller,
    kubernetes_cluster_role_binding.upgrade_controller,
    kubernetes_config_map.upgrade_controller,
    kubectl_manifest.upgrade_crds,
    kubectl_manifest.system_upgrade
  ]
}

locals {
  system_upgrade_name = "system-upgrade-plan"
}

resource "kubectl_manifest" "system_upgrade" {
  yaml_body = <<YAML
    apiVersion: upgrade.cattle.io/v1
    kind: Plan
    metadata:
      name: ${local.system_upgrade_name}
      namespace: system-upgrade
      labels:
        k3s-upgrade: server
    spec:
      channel: https://update.k3s.io/v1-release/channels/stable
      serviceAccountName: system-upgrade
      concurrency: 1
      cordon: true
      drain:
        force: true
        deleteLocalData: true
        ignoreDaemonSets: true
        skipWaitForDeleteTimeout: 270
      upgrade:
        image: rancher/k3s-upgrade
      nodeSelector:
        matchExpressions:
          - key: k3s-upgrade
            operator: Exists
          - key: node-role.kubernetes.io/control-plane
            operator: Exists
          - key: k3s-upgrade
            operator: NotIn
            values:
              - disabled
              - "false"
  YAML

  depends_on = [
    kubernetes_deployment.upgrade_controller,
    kubernetes_service_account.upgrade_controller,
    # kubernetes_secret_v1.upgrade_controller,
    kubernetes_cluster_role_binding.upgrade_controller,
    kubernetes_config_map.upgrade_controller,
    kubectl_manifest.upgrade_crds
  ]
}

