# convertx

A Helm chart for convertx

## Installing the Chart

To install the chart with the release name `my-release`:

```bash
# Standard Helm install
$ helm install  my-release convertx

# To use a custom namespace and force the creation of the namespace
$ helm install my-release --namespace my-namespace --create-namespace convertx

# To use a custom values file
$ helm install my-release -f my-values.yaml convertx
```

See the [Helm documentation](https://helm.sh/docs/intro/using_helm/) for more information on installing and managing the chart.

## Configuration

The following table lists the configurable parameters of the convertx chart and their default values.

| Parameter                                       | Default                    |
| ----------------------------------------------- | -------------------------- |
| `convertx.imagePullPolicy`                      | `IfNotPresent`             |
| `convertx.ingress.class`                        | `-`                        |
| `convertx.ingress.enabled`                      | `false`                    |
| `convertx.ingress.host`                         | `convertx.example.com`     |
| `convertx.ingress.path`                         | `/`                        |
| `convertx.ingress.tls.enabled`                  | `true`                     |
| `convertx.persistence.data.accessMode[0].value` | `ReadWriteOnce`            |
| `convertx.persistence.data.enabled`             | `true`                     |
| `convertx.persistence.data.size`                | `1Gi`                      |
| `convertx.persistence.data.storageClass`        | `-`                        |
| `convertx.replicas`                             | `1`                        |
| `convertx.repository.image`                     | `ghcr.io/c4illin/convertx` |
| `convertx.repository.tag`                       | ``                         |
| `convertx.serviceAccount`                       | ``                         |


