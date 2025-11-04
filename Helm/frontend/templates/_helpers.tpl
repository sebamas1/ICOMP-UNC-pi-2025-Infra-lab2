{{- define "tp1-frontend.name" -}}
tp1-frontend
{{- end }}

{{- define "tp1-frontend.fullname" -}}
{{ include "tp1-frontend.name" . }}
{{- end }}
