echo "Version of prometheus-operator CRDs"

read version

#(
curl "https://raw.githubusercontent.com/prometheus-operator/prometheus-operator/$version/example/prometheus-operator-crd/monitoring.coreos.com_alertmanagerconfigs.yaml" >./crds/alertmanagerconfigs.yaml
curl "https://raw.githubusercontent.com/prometheus-operator/prometheus-operator/$version/example/prometheus-operator-crd/monitoring.coreos.com_alertmanagers.yaml" >./crds/alertmanagers.yaml
curl "https://raw.githubusercontent.com/prometheus-operator/prometheus-operator/$version/example/prometheus-operator-crd/monitoring.coreos.com_podmonitors.yaml" >./crds/podmonitors.yaml
curl "https://raw.githubusercontent.com/prometheus-operator/prometheus-operator/$version/example/prometheus-operator-crd/monitoring.coreos.com_probes.yaml" >./crds/probes.yaml
curl "https://raw.githubusercontent.com/prometheus-operator/prometheus-operator/$version/example/prometheus-operator-crd/monitoring.coreos.com_prometheusagents.yaml" >./crds/prometheusagents.yaml
curl "https://raw.githubusercontent.com/prometheus-operator/prometheus-operator/$version/example/prometheus-operator-crd/monitoring.coreos.com_prometheuses.yaml" >./crds/prometheuses.yaml
curl "https://raw.githubusercontent.com/prometheus-operator/prometheus-operator/$version/example/prometheus-operator-crd/monitoring.coreos.com_prometheusrules.yaml" >./crds/prometheusrules.yaml
curl "https://raw.githubusercontent.com/prometheus-operator/prometheus-operator/$version/example/prometheus-operator-crd/monitoring.coreos.com_scrapeconfigs.yaml" >./crds/scrapeconfigs.yaml
curl "https://raw.githubusercontent.com/prometheus-operator/prometheus-operator/$version/example/prometheus-operator-crd/monitoring.coreos.com_servicemonitors.yaml" >./crds/servicemonitors.yaml
curl "https://raw.githubusercontent.com/prometheus-operator/prometheus-operator/$version/example/prometheus-operator-crd/monitoring.coreos.com_thanosrulers.yaml" >./crds/thanosrulers.yaml
#) >prometheus-crds.yaml
