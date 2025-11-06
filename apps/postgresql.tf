resource "helm_release" "cnpg_operator" {
  name       = "cnpg"
  namespace  = kubernetes_namespace.apps.id
  repository = "https://cloudnative-pg.github.io/charts"
  chart      = "cloudnative-pg"
  version    = "0.26.0"
  values = [
    <<-YAML
      image:
        repository: harbor.stevevaradi.me/ghcr/cloudnative-pg/cloudnative-pg
      imagePullSecrets:
        - name: registry-pass
    YAML
  ]
}

resource "kubernetes_secret" "cnpg_app_user" {
  metadata {
    name      = "cnpg-apps"
    namespace = kubernetes_namespace.apps.id
  }
  type = "kubernetes.io/basic-auth"
  data = {
    username = "apps"
    password = var.postgres_apps_password
  }
}

resource "kubectl_manifest" "cnpg_cluster" {
  yaml_body = <<-YAML
    apiVersion: postgresql.cnpg.io/v1
    kind: Cluster
    metadata:
      name: pg-cnpg
      namespace: apps
    spec:
      instances: 3
      imageName: harbor.stevevaradi.me/stevevaradi/vector-pg:16
      imagePullPolicy: Always
      imagePullSecrets:
        - name: registry-pass
      
      storage:
        size: 50Gi
        storageClass: iscsi-csi
      walStorage:
        size: 10Gi
        storageClass: iscsi-csi

      
      postgresql:
        shared_preload_libraries:
          - pgaudit
          - vchord
          - vectors
        parameters:
          # required by pg_failover_slots
          hot_standby_feedback: "on"

          # enabling the module: any pg_failover_slots.* GUC triggers CNPG
          # to add the library to shared_preload_libraries
          pg_failover_slots.synchronize_slot_names: "name_like:%"  # sync all logical slots

          # strongly recommended to cap WAL retained by slots
          max_slot_wal_keep_size: "10GB"

        # CNPG requires allowing the streaming_replica role to connect to the DB
        # you use with pg_failover_slots; add one line per DB that needs it
        pg_hba:
          - hostssl immich streaming_replica all cert


      managed:
        roles:
          - name: immich
            ensure: present
            login: true
            passwordSecret:
              name: ${kubernetes_secret.immich_password.metadata[0].name}
          - name: mealie
            ensure: present
            login: true
            passwordSecret:
              name: ${kubernetes_secret.mealie_postgres.metadata[0].name}
          - name: penpot
            ensure: present
            login: true
            passwordSecret:
              name: ${kubernetes_secret.penpot_password.metadata[0].name} 
          - name: planka
            ensure: present
            login: true
            passwordSecret:
              name: ${kubernetes_secret.planka_password.metadata[0].name}
      monitoring:
        enablePodMonitor: true
      topologySpreadConstraints:
        - maxSkew: 1
          topologyKey: "kubernetes.io/hostname"
          whenUnsatisfiable: DoNotSchedule
          labelSelector:
            matchLabels:
              cnpg.io/cluster: pg-cnpg
      replicationSlots:
        highAvailability:
          enabled: true
          synchronize: true
          synchronizeLogicalDecoding: true

  YAML

  depends_on = [helm_release.cnpg_operator]
}

