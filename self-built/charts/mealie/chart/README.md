# mealie

A Helm chart for mealie

## Installing the Chart

To install the chart with the release name `my-release`:

```bash
# Standard Helm install
$ helm install  my-release mealie

# To use a custom namespace and force the creation of the namespace
$ helm install my-release --namespace my-namespace --create-namespace mealie

# To use a custom values file
$ helm install my-release -f my-values.yaml mealie
```

See the [Helm documentation](https://helm.sh/docs/intro/using_helm/) for more information on installing and managing the chart.

## Configuration

The following table lists the configurable parameters of the mealie chart and their default values.

| Parameter                                            | Default                         |
| ---------------------------------------------------- | ------------------------------- |
| `mealie.imagePullPolicy`                             | `IfNotPresent`                  |
| `mealie.ingress.class`                               | `-`                             |
| `mealie.ingress.enabled`                             | `false`                         |
| `mealie.ingress.host`                                | `mealie.example.com`            |
| `mealie.ingress.path`                                | `/`                             |
| `mealie.ingress.tls.enabled`                         | `true`                          |
| `mealie.persistence.mealie_data.accessMode[0].value` | `ReadWriteOnce`                 |
| `mealie.persistence.mealie_data.enabled`             | `true`                          |
| `mealie.persistence.mealie_data.size`                | `1Gi`                           |
| `mealie.persistence.mealie_data.storageClass`        | `-`                             |
| `mealie.replicas`                                    | `1`                             |
| `mealie.repository.image`                            | `ghcr.io/mealie-recipes/mealie` |
| `mealie.repository.tag`                              | `v2.8.0`                        |
| `mealie.serviceAccount`                              | ``                              |


