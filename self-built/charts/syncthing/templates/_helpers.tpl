{{- define "syncthing.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" -}}
{{- end }}

{{- define "syncthing.fullname" -}}
{{- printf "%s-%s" .Release.Name (include "syncthing.name" .) | trunc 63 | trimSuffix "-" -}}
{{- end }}

{{- define "syncthing.labels" -}}
app.kubernetes.io/name: {{ include "syncthing.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
helm.sh/chart: {{ printf "%s-%s" .Chart.Name .Chart.Version | quote }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end }}

{{- define "syncthing.selectorLabels" -}}
app.kubernetes.io/name: {{ include "syncthing.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}

# Gateway API capability checks
{{- define "syncthing.hasGateway" -}}
{{- .Capabilities.APIVersions.Has "gateway.networking.k8s.io/v1/Gateway" -}}
{{- end }}

{{- define "syncthing.hasHTTPRoute" -}}
{{- .Capabilities.APIVersions.Has "gateway.networking.k8s.io/v1/HTTPRoute" -}}
{{- end }}

{{- define "syncthing.hasTCPRoute" -}}
{{- or (.Capabilities.APIVersions.Has "gateway.networking.k8s.io/v1alpha2/TCPRoute") (.Capabilities.APIVersions.Has "gateway.networking.k8s.io/v1beta1/TCPRoute") -}}
{{- end }}

{{- define "syncthing.hasUDPRoute" -}}
{{- or (.Capabilities.APIVersions.Has "gateway.networking.k8s.io/v1alpha2/UDPRoute") (.Capabilities.APIVersions.Has "gateway.networking.k8s.io/v1beta1/UDPRoute") -}}
{{- end }}

