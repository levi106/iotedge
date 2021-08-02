{{/* vim: set filetype=mustache: */}}
{{/*
Expand the name of the chart.
*/}}
{{- define "edge-kubernetes.name" -}}
{{- default .Chart.Name | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{/*
Create chart name and version as used by the chart label.
*/}}
{{- define "edge-kubernetes.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{/* Template for iotedged's configuration TOML. */}}
{{- define "edge-kubernetes.iotedgedconfig" }}
homedir = "/var/lib/aziot/edged"
hostname = {{ .Values.iotedged.hostname | default (printf "edgehub.%s.svc.cluster.local" .Release.Namespace ) | quote }}
namespace = {{ include "edge-kubernetes.namespace" . | quote }}
device_hub_selector = ""
config_path = "/etc/edgeAgent"
config_map_name = "iotedged-agent-config"
config_map_volume = "agent-config-volume"
device_id = {{ include "edge-kubernetes.deviceid" . | quote }}
iot_hub_hostname = {{ include "edge-kubernetes.hostname" . | quote }}
{{- with .Values.iotedged.certificates }}
{{ if .secret }}
edge_ca_cert = "aziot-edged-ca"
edge_ca_key = "aziot-edged-ca"
trust_bundle_cert = "aziot-edged-trust-bundle"
{{ end }}
{{ end }}
[provisioning]
{{- range $key, $val := .Values.provisioning }}
{{- if eq $key "attestation"}}
[provisioning.attestation]
{{- range $atkey, $atval := $val }}
{{- if eq $atkey "identityCert" }}
identity_cert = "file:///etc/edge-attestation/identity_cert"
{{- else if eq $atkey "identityPk" }}
identity_pk = "file:///etc/edge-attestation/identity_pk"
{{- else }}
{{ $atkey | snakecase }} = {{$atval | quote }}
{{- end }}
{{- end }}
{{- else if eq $key "authentication" }}
[provisioning.authentication]
{{- range $aukey, $auval := $val }}
{{- if eq $aukey "identityCert" }}
identity_cert = "file:///etc/edge-authentication/identity_cert"
{{- else if eq $aukey "identityPk" }}
identity_pk = "file:///etc/edge-authentication/identity_pk"
{{- else }}
{{ $aukey | snakecase }} = {{$auval | quote }}
{{- end }}
{{- end }}
{{- else }}
{{ $key | snakecase }} = {{- if or (kindIs "float64" $val) (kindIs "bool" $val) }} {{ $val }} {{- else }} {{ $val | quote }}
{{- end }}
{{- end }}
{{- end }}
{{- with .Values.iotedged.certificates }}
{{- if .auto_generated_ca_lifetime_days }}
[edge_ca]
auto_generated_edge_ca_expiry_days = {{ .auto_generated_ca_lifetime_days }}
{{- end }}
{{ end }}
[agent]
name = "edgeAgent"
type = "docker"
{{- if .Values.edgeAgent.env }}
[agent.env]
{{- range $envkey, $envval := .Values.edgeAgent.env }}
{{- if eq $envkey "enableK8sServiceCallTracing"}}
EnableK8sServiceCallTracing = {{ $envval | quote }}
{{- else if eq $envkey "runtimeLogLevel"}}
RuntimeLogLevel = {{ $envval | quote }}
{{- else if eq $envkey "persistentVolumeClaimDefaultSizeInMb"}}
{{- $sizeInMb :=  $envval }}
PersistentVolumeClaimDefaultSizeInMb = {{- if kindIs "float64" $sizeInMb }} {{ printf "%.0f" $sizeInMb | quote }} {{- else }} {{ $sizeInMb | quote }} {{end}}
{{- else if eq $envkey "upstreamProtocol"}}
UpstreamProtocol = {{ $envval | quote }}
{{- else if eq $envkey "useMountSourceForVolumeName"}}
UseMountSourceForVolumeName = {{ $envval | quote }}
{{- else if eq $envkey "storageClassName"}}
StorageClassName = {{- if (eq "-" $envval) }} "" {{- else }} {{ $envval | quote }} {{- end }}
{{- else if eq $envkey "enableExperimentalFeatures" }}
ExperimentalFeatures__Enabled = {{ $envval | quote }}
{{- else if eq $envkey "enableK8sExtensions" }}
ExperimentalFeatures__EnableK8SExtensions = {{ $envval | quote }}
{{- else if eq $envkey "sendRuntimeQualityTelemetry" }}
SendRuntimeQualityTelemetry = {{ $envval | quote }}
{{- else if eq $envkey "runAsNonRoot" }}
RunAsNonRoot = {{ $envval | quote }}
{{- else }}
{{ $envkey }} = {{$envval | quote }}
{{- end }}
{{- end }}
{{ end }}
[agent.config]
image = "{{ .Values.edgeAgent.image.repository }}:{{ .Values.edgeAgent.image.tag }}"

{{- if .Values.edgeAgent.registryCredentials }}
[agent.config.auth]
username = {{ .Values.edgeAgent.registryCredentials.username | quote }}
password = {{ .Values.edgeAgent.registryCredentials.password | quote }}
serveraddress = {{ .Values.edgeAgent.registryCredentials.serveraddress | quote }}

{{ end }}
{{- if .Values.maxRetries }}
[watchdog]
max_retries = {{ .Values.maxRetries }}

{{- end }}
[connect]
workload_uri = "http://localhost:{{ .Values.iotedged.ports.management }}"
management_uri = "http://localhost:{{ .Values.iotedged.ports.workload }}"

[listen]
workload_uri = "http://0.0.0.0:{{ .Values.iotedged.ports.management }}"
management_uri = "http://0.0.0.0:{{ .Values.iotedged.ports.workload }}"

[moby_runtime]
uri = "unix:///var/run/docker.sock"
network = "azure-iot-edge"

[proxy]
image = "{{.Values.iotedgedProxy.image.repository}}:{{.Values.iotedgedProxy.image.tag}}"
image_pull_policy = {{ .Values.iotedgedProxy.image.pullPolicy | quote }}
config_map_name = "iotedged-proxy-config"
config_path = "/etc/iotedge-proxy"
trust_bundle_path = "/etc/trust-bundle"
trust_bundle_config_map_name = "iotedged-proxy-trust-bundle"
{{ end }}

{{/* Template for agent's configuration. */}}
{{- define "edge-kubernetes.agentconfig" }}
AgentConfigPath: "/etc/edgeAgent"
AgentConfigMapName: "iotedged-agent-config"
AgentConfigVolume: "agent-config-volume"
ProxyImage: "{{.Values.iotedgedProxy.image.repository}}:{{.Values.iotedgedProxy.image.tag}}"
ProxyConfigVolume: "config-volume"
ProxyConfigMapName: "iotedged-proxy-config"
ProxyConfigPath: "/etc/iotedge-proxy"
ProxyTrustBundlePath: "/etc/trust-bundle"
ProxyTrustBundleVolume: "trust-bundle-volume"
ProxyTrustBundleConfigMapName: "iotedged-proxy-trust-bundle"
{{- if .Values.iotedgedProxy.resources }}
ProxyResourceRequests:
{{ toYaml .Values.iotedgedProxy.resources | indent 2 }}
{{- end }}
{{- if .Values.edgeAgent.resources }}
AgentResourceRequests:
{{ toYaml .Values.edgeAgent.resources | indent 2 }}
{{- end }}
{{ end }}

{{/* Template for rendering registry credentials. */}}
{{- define "edge-kubernetes.regcreds" }}
auths:
  {{- range $key, $val := .Values.registryCredentials }}
  {{ $key | quote }}:
    auth: {{ printf "%s:%s" $val.username $val.password | b64enc | quote }}
  {{- end }}
{{- end }}

{{/*
Parse the device ID from connection string.
*/}}
{{- define "edge-kubernetes.deviceid" -}}
{{- regexFind "DeviceId=[^;]+" .Values.provisioning.deviceConnectionString | regexFind "=.+" | substr 1 -1 -}}
{{- end -}}

{{/*
Parse the host name from connection string.
*/}}
{{- define "edge-kubernetes.hostname" -}}
{{- regexFind "HostName=[^;]+" .Values.provisioning.deviceConnectionString | regexFind "=.+" | substr 1 -1 -}}
{{- end -}}

{{/*
Parse the hub name from connection string.
*/}}
{{- define "edge-kubernetes.hubname" -}}
{{- include "edge-kubernetes.hostname" . | splitList "." | first | lower -}}
{{- end -}}

{{/*
Parse the Shared Access Key from connection string.
*/}}
{{- define "edge-kubernetes.sharedaccesskey" -}}
{{- regexFind "SharedAccessKey=[^;]+" .Values.provisioning.deviceConnectionString | regexFind "=.+" | substr 1 -1 -}}
{{- end -}}

{{/*
Generate namespace from release namespace parameter.
*/}}
{{- define "edge-kubernetes.namespace" -}}
{{ .Release.Namespace }}
{{- end -}}

{{/* Template for identityd/config.d/00-super.toml. */}}
{{- define "edge-kubernetes.identitydconfig" -}}
hostname = {{ include "edge-kubernetes.hubname" . | quote }}
homedir = "/var/lib/aziot/identityd"

[provisioning]
source = "manual"
iothub_hostname = {{ include "edge-kubernetes.hostname" . | quote }}
device_id = {{ include "edge-kubernetes.deviceid" . | quote }}
{{- if .Values.iotedged.parentHostname }}
local_gateway_hostname = {{ .Values.iotedged.parentHostname | quote }}
{{- end }}

[provisioning.authentication]
method = "sas"
device_id_pk = "device-id"

[[principal]]
uid = 992
name = "aziot-edge"
{{- end -}}

{{/* Template for keyd/config.d/00-super.toml. */}}
{{- define "edge-kubernetes.keydconfig" -}}
[aziot_keys]
homedir_path = "/var/lib/aziot/keyd"

[preloaded_keys]
{{- with .Values.iotedged.certificates }}
{{- if .secret }}
aziot-edged-ca = "file:///etc/aziot/certificates/aziot-edged-ca.key.pem"
{{- end }}
{{ end }}
device-id = "file:///var/secrets/aziot/keyd/device-id"

[[principal]]
uid = 993
keys = ["aziot_identityd_master_id", "device-id"]

[[principal]]
uid = 992
keys = ["aziot-edged-ca", "iotedge_master_encryption_id"]

[[principal]]
uid = 994
keys = ["aziot-edged-ca"]
{{- end -}}

{{/* Template for certd/config.d/00-super.toml. */}}
{{- define "edge-kubernetes.certdconfig" -}}
homedir_path = "/var/lib/aziot/certd"
[cert_issuance.aziot-edged-ca]
method = "self_signed"
common_name = "iotedged workload ca {{- include "edge-kubernetes.hubname" . }}"
expiry_days = 90

[preloaded_certs]
aziot-edged-trust-bundle = ["aziot-edged-ca"]
{{- with .Values.iotedged.certificates }}
{{- if .secret }}
aziot-edged-ca = "file:///etc/aziot/certificates/aziot-edged-ca.full-chain.cert.pem"
trust-bundle-user = "file:///etc/aziot/certificates/iotedge_config_cli_root.pem"
{{- end }}
{{ end }}

[[principal]]
uid = 992
certs = ["aziot-edged-ca", "aziot-edged/module/*"]
{{- end -}}