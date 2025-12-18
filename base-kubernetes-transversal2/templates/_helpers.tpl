{{/*
Expand the name of the chart.
*/}}
{{- define "eks-controllers.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Create a default fully qualified app name.
We truncate at 63 chars because some Kubernetes name fields are limited to this (by the DNS naming spec).
If release name contains chart name it will be used as a full name.
*/}}
{{- define "eks-controllers.fullname" -}}
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
Create chart name and version as used by the chart label.
*/}}
{{- define "eks-controllers.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Common labels
*/}}
{{- define "eks-controllers.labels" -}}
helm.sh/chart: {{ include "eks-controllers.chart" . }}
{{ include "eks-controllers.selectorLabels" . }}
{{- if .Chart.AppVersion }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
{{- end }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end }}

{{/*
Selector labels
*/}}
{{- define "eks-controllers.selectorLabels" -}}
app.kubernetes.io/name: {{ include "eks-controllers.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}

{{/*
Create the name of the service account to use
*/}}
{{- define "eks-controllers.serviceAccountName" -}}
{{- if .Values.serviceAccount.create }}
{{- default (include "eks-controllers.fullname" .) .Values.serviceAccount.name }}
{{- else }}
{{- default "default" .Values.serviceAccount.name }}
{{- end }}
{{- end }}

{{/*
NodePool name
*/}}
{{- define "eks-controllers.nodepool.name" -}}
{{- if .Values.nodepool.nameOverride }}
{{- .Values.nodepool.nameOverride | trunc 63 | trimSuffix "-" }}
{{- else }}
{{- printf "%s-nodepool" (include "eks-controllers.fullname" .) | trunc 63 | trimSuffix "-" }}
{{- end }}
{{- end }}

{{/*
NodeClass name
*/}}
{{- define "eks-controllers.nodeclass.name" -}}
{{- if .Values.nodeclass.nameOverride }}
{{- .Values.nodeclass.nameOverride | trunc 63 | trimSuffix "-" }}
{{- else }}
{{- printf "%s-nodeclass" (include "eks-controllers.fullname" .) | trunc 63 | trimSuffix "-" }}
{{- end }}
{{- end }}
