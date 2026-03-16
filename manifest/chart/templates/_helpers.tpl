{{- define "glassbox-mol-audit.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{- define "glassbox-mol-audit.fullname" -}}
{{- if .Values.fullnameOverride -}}
{{- .Values.fullnameOverride | trunc 63 | trimSuffix "-" -}}
{{- else -}}
{{- .Release.Name | trunc 63 | trimSuffix "-" -}}
{{- end -}}
{{- end -}}

{{- define "glassbox-mol-audit.labels" -}}
app.kubernetes.io/name: {{ include "glassbox-mol-audit.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
app.kubernetes.io/part-of: glassbox-marketplace
{{- end -}}

{{- define "glassbox-mol-audit.partnerSolutionLabel" -}}
{{- default "isol_plb32_001kf00001e8runiab_pwayyor5jqd3hikviwgqy5hwrx2hnpn5" .Values.marketplace.partnerSolutionLabel -}}
{{- end -}}

{{- define "glassbox-mol-audit.podLabels" -}}
{{- include "glassbox-mol-audit.labels" . }}
{{- $partnerLabel := include "glassbox-mol-audit.partnerSolutionLabel" . | trim -}}
{{- if $partnerLabel }}
goog-partner-solution: {{ $partnerLabel | quote }}
{{- end }}
{{- end -}}

{{- define "glassbox-mol-audit.serviceAccountName" -}}
{{- if .Values.serviceAccount.name -}}
{{- .Values.serviceAccount.name -}}
{{- else -}}
{{- printf "%s-sa" (include "glassbox-mol-audit.fullname" .) -}}
{{- end -}}
{{- end -}}

{{- define "glassbox-mol-audit.runnerImageRepository" -}}
{{- $mode := default "standard" .Values.config.runMode -}}
{{- if eq $mode "deep" -}}
  {{- if and .Values.image.deep .Values.image.deep.repository -}}
    {{- .Values.image.deep.repository -}}
  {{- else -}}
    {{- .Values.image.repository -}}
  {{- end -}}
{{- else -}}
  {{- if and .Values.image.standard .Values.image.standard.repository -}}
    {{- .Values.image.standard.repository -}}
  {{- else -}}
    {{- .Values.image.repository -}}
  {{- end -}}
{{- end -}}
{{- end -}}

{{- define "glassbox-mol-audit.runnerImageTag" -}}
{{- $mode := default "standard" .Values.config.runMode -}}
{{- if eq $mode "deep" -}}
  {{- if and .Values.image.deep (hasKey .Values.image.deep "tag") -}}
    {{- .Values.image.deep.tag -}}
  {{- else -}}
    {{- .Values.image.tag -}}
  {{- end -}}
{{- else -}}
  {{- if and .Values.image.standard (hasKey .Values.image.standard "tag") -}}
    {{- .Values.image.standard.tag -}}
  {{- else -}}
    {{- .Values.image.tag -}}
  {{- end -}}
{{- end -}}
{{- end -}}

{{- define "glassbox-mol-audit.runnerImageDigest" -}}
{{- $mode := default "standard" .Values.config.runMode -}}
{{- if eq $mode "deep" -}}
  {{- if and .Values.image.deep (hasKey .Values.image.deep "digest") -}}
    {{- .Values.image.deep.digest -}}
  {{- else -}}
    {{- .Values.image.digest -}}
  {{- end -}}
{{- else -}}
  {{- if and .Values.image.standard (hasKey .Values.image.standard "digest") -}}
    {{- .Values.image.standard.digest -}}
  {{- else -}}
    {{- .Values.image.digest -}}
  {{- end -}}
{{- end -}}
{{- end -}}

{{- define "glassbox-mol-audit.runnerImagePullPolicy" -}}
{{- $mode := default "standard" .Values.config.runMode -}}
{{- if eq $mode "deep" -}}
  {{- if and .Values.image.deep .Values.image.deep.pullPolicy -}}
    {{- .Values.image.deep.pullPolicy -}}
  {{- else -}}
    {{- .Values.image.pullPolicy -}}
  {{- end -}}
{{- else -}}
  {{- if and .Values.image.standard .Values.image.standard.pullPolicy -}}
    {{- .Values.image.standard.pullPolicy -}}
  {{- else -}}
    {{- .Values.image.pullPolicy -}}
  {{- end -}}
{{- end -}}
{{- end -}}
