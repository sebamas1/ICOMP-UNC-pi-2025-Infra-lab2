{{- define "tp1-backend.name" -}}
tp1-backend
{{- end }}

{{- define "tp1-backend.fullname" -}}
{{ include "tp1-backend.name" . }}
{{- end }}
