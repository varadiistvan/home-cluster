terraform {
  required_providers {
    helm = {
      source = "hashicorp/helm"
    }
    kubernetes = {
      source = "hashicorp/kubernetes"
    }
    kubectl = {
      source = "alekc/kubectl"
    }
  }
}


resource "kubernetes_namespace" "hardware" {
  metadata {
    name = "hardware"
  }
}

resource "helm_release" "nfd" {
  name       = "nfd"
  namespace  = kubernetes_namespace.hardware.id
  chart      = "node-feature-discovery"
  repository = "https://kubernetes-sigs.github.io/node-feature-discovery/charts"
  version    = "0.17.3"
  values     = [file("${path.module}/nfd-values.yaml")]
}

data "http" "intel_rules" {
  url = "https://raw.githubusercontent.com/intel/intel-device-plugins-for-kubernetes/refs/heads/release-0.34/deployments/nfd/overlays/node-feature-rules/node-feature-rules.yaml"
}

resource "kubectl_manifest" "intel_rules" {
  yaml_body = data.http.intel_rules.response_body

  depends_on = [helm_release.nfd]
}

resource "helm_release" "intel_device_operator" {
  name       = "intel-device-operator"
  namespace  = kubernetes_namespace.hardware.id
  chart      = "intel-device-plugins-operator"
  repository = "https://intel.github.io/helm-charts"
  version    = "0.34.0"
  values     = [file("${path.module}/intel-values.yaml")]

  depends_on = [helm_release.nfd, kubectl_manifest.intel_rules]
}

resource "kubectl_manifest" "intel_gpu_plugin" {
  yaml_body = <<-YAML
    apiVersion: deviceplugin.intel.com/v1
    kind: GpuDevicePlugin
    metadata:
      name: gpudeviceplugin
    spec:
      image: intel/intel-gpu-plugin:0.34.0
      sharedDevNum: 10
      logLevel: 4
      enableMonitoring: true
      nodeSelector:
        intel.feature.node.kubernetes.io/gpu: "true"
  YAML

  depends_on = [helm_release.intel_device_operator]
}
