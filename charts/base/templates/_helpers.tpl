{{/* vim: set filetype=mustache: */}}
{{/*
Expand the name of the chart.
*/}}
{{- define "base.name" -}}
{{- default .Release.Name .Values.nameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Create a default fully qualified app name.
We truncate at 63 chars because some Kubernetes name fields are limited to this (by the DNS naming spec).
If release name contains chart name it will be used as a full name.
*/}}
{{- define "base.fullname" -}}
{{- if .Values.fullnameOverride }}
{{- .Values.fullnameOverride | trunc 63 | trimSuffix "-" }}
{{- else }}
{{- .Release.Name | trunc 63 | trimSuffix "-" }}
{{- end }}
{{- end }}

{{/*
Create chart name and version as used by the chart label.
*/}}
{{- define "base.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
labels
*/}}
{{- define "base.labels" -}}
{{- $commonValues := include "base.commonLabels" . | trim | fromYaml -}}
{{- $selectorLabels := include "base.selectorLabels" . | trim | fromYaml -}}
{{- $allLabels := mustMerge $selectorLabels $commonValues -}}
{{- range $key, $value := $allLabels }}
{{ $key }}: {{ $value | quote }}
{{- end }}
{{- end }}

{{/*
Common labels
*/}}
{{- define "base.commonLabels" -}}
{{- if .Values.labels }}
{{- range $key, $value := .Values.labels }}
{{ $key }}: {{ $value | quote }}
{{- end }}
{{- else }}
helm.sh/chart: {{ include "base.chart" . }}
app.kubernetes.io/name: {{ include "base.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- if .Chart.AppVersion }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
{{- else if .Values.image }}
{{- if .Values.image.tag }}
app.kubernetes.io/version: {{ .Values.image.tag | quote }}
{{- end }}
{{- end }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end }}
{{- end }}

{{/*
Selector labels
*/}}
{{- define "base.selectorLabels" -}}
{{- if .Values.selectorLabels }}
{{- range $key, $value := .Values.selectorLabels }}
{{ $key }}: {{ $value | quote }}
{{- end }}
{{- else }}
app: {{ include "base.fullname" . }}
{{- end }}
{{- end }}

{{/*
service port default
*/}}
{{- define "base.servicePortDefaultNum" -}}
{{- $serviceValues := .Values.service | default dict -}}
{{- if $serviceValues.ports }}
{{- with (index $serviceValues.ports 0) }}
{{- .port }}
{{- end }}
{{- else if .Values.ports }}
{{- with (index .Values.ports 0) }}
{{- .containerPort }}
{{- end }}
{{- else }}
{{- printf "80" }}
{{- end }}
{{- end }}

{{/*
range values pairs
*/}}
{{- define "base.valuesPairs" -}}
{{- range $key, $value := . }}
{{ $key }}: {{ $value | quote }}
{{- end }}
{{- end }}

{{/*
Datadog OpenMetrics Autodiscovery annotation generated from .Values.shipMetrics.
shipMetrics can be a list of metric names, a map of metric names, or a map with a metrics key.
*/}}
{{- define "base.shipMetricsAnnotation" -}}
{{- $root := . -}}
{{- with $root.Values.shipMetrics }}
{{- $shipMetrics := . -}}
{{- $config := dict -}}
{{- $metricsSource := $shipMetrics -}}
{{- if kindIs "map" $shipMetrics }}
{{- $config = $shipMetrics -}}
{{- if hasKey $shipMetrics "metrics" }}
{{- $metricsSource = get $shipMetrics "metrics" -}}
{{- else }}
{{- $metricsSource = dict -}}
{{- $reservedKeys := list "metrics" "containerName" "container" "openmetrics_endpoint" "openmetricsEndpoint" "endpoint" "port" "path" "scheme" "namespace" "init_config" "initConfig" -}}
{{- range $key, $value := $shipMetrics }}
{{- if not (has $key $reservedKeys) }}
{{- $_ := set $metricsSource $key $value -}}
{{- end }}
{{- end }}
{{- end }}
{{- end }}
{{- $metrics := list -}}
{{- if kindIs "slice" $metricsSource }}
{{- $metrics = $metricsSource -}}
{{- else if kindIs "map" $metricsSource }}
{{- range $metricName := keys $metricsSource | sortAlpha }}
{{- $metricValue := get $metricsSource $metricName -}}
{{- if kindIs "bool" $metricValue }}
{{- if $metricValue }}
{{- $metrics = append $metrics $metricName -}}
{{- end }}
{{- else if empty $metricValue }}
{{- $metrics = append $metrics $metricName -}}
{{- else }}
{{- $metrics = append $metrics (dict $metricName $metricValue) -}}
{{- end }}
{{- end }}
{{- else if $metricsSource }}
{{- $metrics = list $metricsSource -}}
{{- end }}
{{- if $metrics }}
{{- $containerName := coalesce (get $config "containerName") (get $config "container") (include "base.name" $root) -}}
{{- $scheme := get $config "scheme" | default "http" -}}
{{- $port := get $config "port" | default "8002" | toString -}}
{{- $path := get $config "path" | default "/metrics" -}}
{{- $endpoint := coalesce (get $config "openmetrics_endpoint") (get $config "openmetricsEndpoint") (get $config "endpoint") (printf "%s://%%%%host%%%%:%s%s" $scheme $port $path) -}}
{{- $namespace := get $config "namespace" | default "" -}}
{{- $initConfig := dict -}}
{{- if hasKey $config "init_config" }}
{{- $initConfig = get $config "init_config" -}}
{{- else if hasKey $config "initConfig" }}
{{- $initConfig = get $config "initConfig" -}}
{{- end }}
{{- $instance := dict "openmetrics_endpoint" $endpoint "namespace" $namespace "metrics" $metrics -}}
{{- $checks := dict "openmetrics" (dict "init_config" $initConfig "instances" (list $instance)) -}}
ad.datadoghq.com/{{ $containerName }}.checks: |
{{ $checks | toPrettyJson | indent 2 }}
{{- end }}
{{- end }}
{{- end }}

{{/*
Pod annotations shared by workload templates.
*/}}
{{- define "base.podAnnotations" -}}
{{- $annotations := list -}}
{{- if .Values.prometheusScrape -}}
{{- $prometheusAnnotations := printf "prometheus.io/path: %s\nprometheus.io/port: %s\nprometheus.io/scrape: \"true\"" (.Values.prometheusScrapePath | quote) (.Values.prometheusScrapePort | quote) -}}
{{- $annotations = append $annotations $prometheusAnnotations -}}
{{- end -}}
{{- with .Values.podAnnotations -}}
{{- $annotations = append $annotations (include "base.valuesPairs" . | trim) -}}
{{- end -}}
{{- with (include "base.shipMetricsAnnotation" . | trim) -}}
{{- $annotations = append $annotations . -}}
{{- end -}}
{{- join "\n" $annotations -}}
{{- end }}

{{/*
raw.resource will create a resource template that can be
merged with each item in `.Values.resources`.
*/}}
{{- define "raw.resource" -}}
metadata:
  labels:
    {{- include "base.commonLabels" . | trim | nindent 4 }}
{{- end }}

{{/*
Return the kind of the resource.
StatefulSet or Deployment.
*/}}
{{- define "base.kind" -}}
{{- if .Values.kind }}
{{- .Values.kind }}
{{- else if .Values.statefulSet }}
{{- printf "StatefulSet" }}
{{- else }}
{{- printf "Deployment" }}
{{- end }}
{{- end }}
