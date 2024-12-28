echo "Version of prometheus-operator CRDs"

read version

(
  curl "https://raw.githubusercontent.com/prometheus-operator/prometheus-operator/$version/example/prometheus-operator-crd/monitoring.coreos.com_alertmanagerconfigs.yaml"
  curl "https://raw.githubusercontent.com/prometheus-operator/prometheus-operator/$version/example/prometheus-operator-crd/monitoring.coreos.com_alertmanagers.yaml"
  curl "https://raw.githubusercontent.com/prometheus-operator/prometheus-operator/$version/example/prometheus-operator-crd/monitoring.coreos.com_podmonitors.yaml"
  curl "https://raw.githubusercontent.com/prometheus-operator/prometheus-operator/$version/example/prometheus-operator-crd/monitoring.coreos.com_probes.yaml"
  curl "https://raw.githubusercontent.com/prometheus-operator/prometheus-operator/$version/example/prometheus-operator-crd/monitoring.coreos.com_prometheusagents.yaml"
  curl "https://raw.githubusercontent.com/prometheus-operator/prometheus-operator/$version/example/prometheus-operator-crd/monitoring.coreos.com_prometheuses.yaml"
  curl "https://raw.githubusercontent.com/prometheus-operator/prometheus-operator/$version/example/prometheus-operator-crd/monitoring.coreos.com_prometheusrules.yaml"
  curl "https://raw.githubusercontent.com/prometheus-operator/prometheus-operator/$version/example/prometheus-operator-crd/monitoring.coreos.com_scrapeconfigs.yaml"
  curl "https://raw.githubusercontent.com/prometheus-operator/prometheus-operator/$version/example/prometheus-operator-crd/monitoring.coreos.com_servicemonitors.yaml"
  curl "https://raw.githubusercontent.com/prometheus-operator/prometheus-operator/$version/example/prometheus-operator-crd/monitoring.coreos.com_thanosrulers.yaml"
) >prometheus-crds.yaml
