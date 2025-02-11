{{- define "pi5-monitor.fullname" -}}
{{- if eq .Release.Name "pi5-monitor" -}}
pi5-monitor
{{- else -}}
{{ .Release.Name }}-pi5-monitor
{{- end -}}
{{- end }}

{{- define "pi5-monitor.labels" -}}
app: pi5-monitor
chart: {{ .Chart.Name }}-{{ .Chart.Version }}
release: {{ .Release.Name }}
{{- end }}

{{- define "pi5-monitor.selectorLabels" -}}
app: pi5-monitor
{{- end }}
