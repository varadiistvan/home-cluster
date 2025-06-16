{{- /*
Chart name and version
*/}}
{{- define "csi-provisioner.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}

{{- define "csi-provisioner.fullname" -}}
{{- $name := default .Chart.Name .Values.nameOverride }}
{{- if contains $name .Release.Name }}
{{- .Release.Name | trunc 63 | trimSuffix "-" }}
{{- else }}
{{- printf "%s-%s" .Release.Name $name | trunc 63 | trimSuffix "-" }}
{{- end }}
{{- end }}

{{- define "csi-provisioner.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
{{- end }}

{{- /*
Common labels
*/}}
{{- define "csi-provisioner.labels" -}}
helm.sh/chart: {{ include "csi-provisioner.chart" . }}
{{ include "csi-provisioner.selectorLabels" . }}
{{- if .Chart.AppVersion }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
{{- end }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end }}

{{- define "csi-provisioner.selectorLabels" -}}
app.kubernetes.io/name: {{ include "csi-provisioner.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}

{{- /*
Service Account names
*/}}
{{- define "csi-provisioner.controllerServiceAccountName" -}}
{{- if and .Values.rbac .Values.rbac.controllerServiceAccount .Values.rbac.controllerServiceAccount.name }}
{{- .Values.rbac.controllerServiceAccount.name }}
{{- else }}
{{- printf "%s-controller" (include "csi-provisioner.fullname" .) }}
{{- end }}
{{- end }}

{{- define "csi-provisioner.nodeServiceAccountName" -}}
{{- if and .Values.rbac .Values.rbac.nodeServiceAccount .Values.rbac.nodeServiceAccount.name }}
{{- .Values.rbac.nodeServiceAccount.name }}
{{- else }}
{{- printf "%s-node" (include "csi-provisioner.fullname" .) }}
{{- end }}
{{- end }}
