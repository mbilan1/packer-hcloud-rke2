{{/*
Expand the name of the chart.
*/}}
{{- define "golden-image-controller.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Create a default fully qualified app name.
*/}}
{{- define "golden-image-controller.fullname" -}}
{{- if .Values.fullnameOverride }}
{{- .Values.fullnameOverride | trunc 63 | trimSuffix "-" }}
{{- else }}
{{- $name := default .Chart.Name .Values.nameOverride }}
{{- if contains $name .Release.Name }}
{{- .Release.Name | trunc 63 | trimSuffix "-" }}
{{- else }}
{{- printf "%s-%s" .Release.Name $name | trunc 63 | trimSuffix "-" }}
{{- end }}
{{- end }}
{{- end }}

{{/*
Common labels.
*/}}
{{- define "golden-image-controller.labels" -}}
helm.sh/chart: {{ .Chart.Name }}-{{ .Chart.Version | replace "+" "_" }}
{{ include "golden-image-controller.selectorLabels" . }}
app.kubernetes.io/version: {{ default "unknown" .Chart.AppVersion | quote }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end }}

{{/*
Selector labels.
*/}}
{{- define "golden-image-controller.selectorLabels" -}}
app.kubernetes.io/name: {{ include "golden-image-controller.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}

{{/*
Service account name.
*/}}
{{- define "golden-image-controller.serviceAccountName" -}}
{{- if .Values.serviceAccount.create }}
{{- default (include "golden-image-controller.fullname" .) .Values.serviceAccount.name }}
{{- else }}
{{- default "default" .Values.serviceAccount.name }}
{{- end }}
{{- end }}

{{/*
Controller namespace.
*/}}
{{- define "golden-image-controller.namespace" -}}
{{- .Values.namespace | default "golden-image-system" }}
{{- end }}

{{/*
Builder image reference.
*/}}
{{- define "golden-image-controller.builderImage" -}}
{{ .Values.builder.image.repository }}:{{ .Values.builder.image.tag }}
{{- end }}
