{{/* Expand the name of the chart. */}}
{{- define "knowledge-worker.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}
{{/* Create a default fully qualified app name. */}}
{{- define "knowledge-worker.fullname" -}}
{{- printf "%s-%s" .Release.Name (include "knowledge-worker.name" .) | trunc 63 | trimSuffix "-" }}
{{- end }}
{{/* Common labels */}}
{{- define "knowledge-worker.labels" -}}
helm.sh/chart: {{ printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
{{ include "knowledge-worker.selectorLabels" . }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end }}
{{/* Selector labels */}}
{{- define "knowledge-worker.selectorLabels" -}}
app.kubernetes.io/name: {{ include "knowledge-worker.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}
