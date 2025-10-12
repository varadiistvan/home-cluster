locals {
  # 1) Read & normalize newlines
  body_norm = replace(file("${path.module}/gateway/standard-install.yaml"), "\r\n", "\n")

  # 2) Split on canonical separators; pad with \n so leading/trailing --- become empty chunks we drop
  raw_docs = split("\n---\n", "\n${local.body_norm}\n")

  # 3) Strip blank lines, comment lines, and YAML end markers ("...") from each chunk
  cleaned_docs = [
    for d in local.raw_docs : (
      # join back the kept lines
      join("\n", [
        for line in split("\n", d) :
        line
        if(
          trimspace(line) != "" &&
          !startswith(trimspace(line), "#") &&
          trimspace(line) != "..."
        )
      ])
    )
    # keep only non-empty results
    if length(
      join("\n", [
        for line in split("\n", d) :
        line
        if(
          trimspace(line) != "" &&
          !startswith(trimspace(line), "#") &&
          trimspace(line) != "..."
        )
      ])
    ) > 0
  ]

  # 4) Decode; expand "kind: List" into its items
  objs_expanded = flatten([
    for doc in local.cleaned_docs : (
      try(yamldecode(doc).kind, "") == "List" && can(yamldecode(doc).items)
      ? yamldecode(doc).items
      : [yamldecode(doc)]
    )
  ])

  # 5) Stable keys known at plan time -> index map
  objs_by_index = { for i, o in local.objs_expanded : i => o }

  # 6) Split CRDs vs everything else
  gateway_crd_docs   = { for i, o in local.objs_by_index : i => o if try(o.kind, "") == "CustomResourceDefinition" }
  gateway_other_docs = { for i, o in local.objs_by_index : i => o if try(o.kind, "") != "CustomResourceDefinition" }
}

resource "kubectl_manifest" "gateway_api_crds" {
  for_each  = local.gateway_crd_docs
  yaml_body = yamlencode(each.value)
}

resource "kubectl_manifest" "gateway_api_other" {
  for_each   = local.gateway_other_docs
  yaml_body  = yamlencode(each.value)
  depends_on = [kubectl_manifest.gateway_api_crds]
}




resource "helm_release" "cilium" {
  name       = "cilium"
  namespace  = "kube-system"
  chart      = "cilium"
  version    = "1.18.2"
  repository = "https://helm.cilium.io/"
  values     = [file("${path.module}/cilium-values.yaml")]
  timeout    = 300

  depends_on = [kubectl_manifest.ca_issuer, kubectl_manifest.gateway_api_crds]
}

resource "kubectl_manifest" "main_ingress_ip_pool" {
  yaml_body = <<-YAML
    apiVersion: cilium.io/v2
    kind: CiliumLoadBalancerIPPool
    metadata:
      name: vip-192-168-0-152
    spec:
      blocks:
        - start: "192.168.0.152"
          stop:  "192.168.0.152"
  YAML

  depends_on = [helm_release.cilium]
}

resource "kubectl_manifest" "main_ingresS_l2ap" {
  yaml_body = <<-YAML
    apiVersion: cilium.io/v2alpha1
    kind: CiliumL2AnnouncementPolicy
    metadata:
      name: announce-ingress
    spec:
      loadBalancerIPs: true
      externalIPs: false
  YAML

  depends_on = [kubectl_manifest.main_ingress_ip_pool]
}
