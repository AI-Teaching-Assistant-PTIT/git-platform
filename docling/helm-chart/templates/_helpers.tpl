{{/* Expand the name of the chart. */}}
{{- define "docling.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}
{{/* Create a default fully qualified app name. */}}
{{- define "docling.fullname" -}}
{{- printf "%s-%s" .Release.Name (include "docling.name" .) | trunc 63 | trimSuffix "-" }}
{{- end }}
{{/* Common labels */}}
{{- define "docling.labels" -}}
helm.sh/chart: {{ printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
{{ include "docling.selectorLabels" . }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end }}
{{/* Selector labels */}}
{{- define "docling.selectorLabels" -}}
app.kubernetes.io/name: {{ include "docling.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}
