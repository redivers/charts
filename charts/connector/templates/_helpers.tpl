{{/*
Expand the name of the chart.
*/}}
{{- define "connector.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Validate connector values before rendering resources.
*/}}
{{- define "connector.validateValues" -}}
{{- if and (not .Values.existingSecret) (not .Values.rediver.token) -}}
{{- fail "rediver.token is required (or set existingSecret to reference a pre-created Secret with REDIVER_TOKEN)." -}}
{{- end -}}
{{- if not (.Values.rediver.url | toString | trim) -}}
{{- fail "rediver.url must not be empty." -}}
{{- end -}}
{{- if not .Values.existingSecret -}}
{{- $gitlabUrlConfigured := ne (.Values.gitlab.url | toString | trim) "" -}}
{{- $gitlabTokenConfigured := ne (.Values.gitlab.token | toString | trim) "" -}}
{{- if ne $gitlabUrlConfigured $gitlabTokenConfigured -}}
{{- fail "gitlab.url and gitlab.token must be set together when the chart manages the Secret." -}}
{{- end -}}
{{- end -}}
{{- $threads := .Values.config.threads | toString -}}
{{- if and $threads (not (regexMatch "^[1-9][0-9]*$" $threads)) -}}
{{- fail "config.threads must be a positive integer when set." -}}
{{- end -}}
{{- if not (has .Values.config.logLevel (list "debug" "info" "warn" "error")) -}}
{{- fail "config.logLevel must be one of debug, info, warn, error." -}}
{{- end -}}
{{- $shutdownGrace := .Values.config.shutdownGraceSeconds | toString -}}
{{- if not (regexMatch "^[1-9][0-9]*$" $shutdownGrace) -}}
{{- fail "config.shutdownGraceSeconds must be a positive integer." -}}
{{- end -}}
{{- $projectsPerPage := .Values.gitlab.projectsPerPage | toString -}}
{{- if or (not (regexMatch "^[1-9][0-9]*$" $projectsPerPage)) (gt (int $projectsPerPage) 100) -}}
{{- fail "gitlab.projectsPerPage must be between 1 and 100." -}}
{{- end -}}
{{- end -}}

{{/*
Create a default fully qualified app name.
*/}}
{{- define "connector.fullname" -}}
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
Chart name and version label.
*/}}
{{- define "connector.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Common labels.
*/}}
{{- define "connector.labels" -}}
helm.sh/chart: {{ include "connector.chart" . }}
{{ include "connector.selectorLabels" . }}
{{- if .Chart.AppVersion }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
{{- end }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end }}

{{/*
Selector labels.
*/}}
{{- define "connector.selectorLabels" -}}
app.kubernetes.io/name: {{ include "connector.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}

{{/*
Name of the ServiceAccount to use.
*/}}
{{- define "connector.serviceAccountName" -}}
{{- if .Values.serviceAccount.create }}
{{- default (include "connector.fullname" .) .Values.serviceAccount.name }}
{{- else }}
{{- default "default" .Values.serviceAccount.name }}
{{- end }}
{{- end }}

{{/*
Name of the Secret holding tokens (created one, or a user-supplied existing one).
*/}}
{{- define "connector.secretName" -}}
{{- if .Values.existingSecret }}
{{- .Values.existingSecret }}
{{- else }}
{{- include "connector.fullname" . }}
{{- end }}
{{- end }}
