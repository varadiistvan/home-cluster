# endless_wiki

A Helm chart for endless_wiki

## Installing the Chart

To install the chart with the release name `my-release`:

```bash
# Standard Helm install
$ helm install  my-release endless_wiki

# To use a custom namespace and force the creation of the namespace
$ helm install my-release --namespace my-namespace --create-namespace endless_wiki

# To use a custom values file
$ helm install my-release -f my-values.yaml endless_wiki
```

See the [Helm documentation](https://helm.sh/docs/intro/using_helm/) for more information on installing and managing the chart.

## Configuration

The following table lists the configurable parameters of the endless_wiki chart and their default values.

| Parameter                               | Default                     |
| --------------------------------------- | --------------------------- |
| `endless_wiki.environment.OLLAMA_HOST`  | `http://ollama:11434`       |
| `endless_wiki.environment.OLLAMA_MODEL` | `gemma3:1b`                 |
| `endless_wiki.imagePullPolicy`          | `IfNotPresent`              |
| `endless_wiki.ingress.class`            | `-`                         |
| `endless_wiki.ingress.enabled`          | `false`                     |
| `endless_wiki.ingress.host`             | `wiki.stevevaradi.me`       |
| `endless_wiki.ingress.path`             | `/`                         |
| `endless_wiki.ingress.tls.enabled`      | `true`                      |
| `endless_wiki.ingress.tls.secretName`   | ``                          |
| `endless_wiki.replicas`                 | `1`                         |
| `endless_wiki.repository.image`         | `xanderstrike/endless-wiki` |
| `endless_wiki.repository.tag`           | `latest`                    |
| `endless_wiki.serviceAccount`           | ``                          |


