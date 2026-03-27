{{- define "base.datadogMetric" -}}
{{- if .Values.datadogMetric.enabled }}
---
apiVersion: {{ .Values.datadogMetric.apiVersion | default "datadoghq.com/v1alpha1" }}
kind: DatadogMetric
metadata:
  name: {{ .Values.datadogMetric.name | default (include "base.fullname" .) }}
  {{- if .Values.datadogMetric.namespace }}
  namespace: {{ .Values.datadogMetric.namespace }}
  {{- else if .Values.namespace }}
  namespace: {{ .Values.namespace }}
  {{- end }}
  labels:
    {{- include "base.labels" . | trim | nindent 4 }}
  {{- with .Values.datadogMetric.annotations }}
  annotations:
    {{- toYaml . | nindent 4 }}
  {{- end }}
{{- with .Values.datadogMetric.spec }}
spec:
  {{- toYaml . | nindent 2 }}
{{- end }}
{{- end }}
{{- end }}
