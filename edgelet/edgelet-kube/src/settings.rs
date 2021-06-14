// Copyright (c) Microsoft. All rights reserved.

use std::path::Path;

use crate::error::Error;
use crate::ErrorKind;
use docker::models::AuthConfig;
use edgelet_core::{
    settings::AutoReprovisioningMode, Connect, Endpoints, Listen, ModuleSpec, RuntimeSettings,
    Settings as BaseSettings, WatchdogSettings,
};
use failure::{Context, Fail};
use edgelet_docker::{DockerConfig, CONFIG_FILE_DEFAULT};
use k8s_openapi::api::core::v1::ResourceRequirements;

#[derive(Clone, Debug, serde_derive::Deserialize, serde_derive::Serialize)]
pub struct Settings {
    #[serde(flatten)]
    base: BaseSettings<DockerConfig>,
    namespace: String,
    iot_hub_hostname: Option<String>,
    device_id: Option<String>,
    device_hub_selector: String,
    proxy: ProxySettings,
    config_path: String,
    config_map_name: String,
    config_map_volume: String,
    resources: Option<ResourceRequirements>,
    #[serde(default = "Settings::default_nodes_rbac")]
    has_nodes_rbac: bool,
}

impl Settings {
    /// Load the aziot-edged configuration.
    ///
    /// Configuration is made up of /etc/aziot/edged/config.toml (overridden by the `AZIOT_EDGED_CONFIG` env var)
    /// and any files in the /etc/aziot/edged/config.d directory (overridden by the `AZIOT_EDGED_CONFIG_DIR` env var).
    pub fn new() -> Result<Self, LoadSettingsError> {
        const CONFIG_ENV_VAR: &str = "AZIOT_EDGED_CONFIG";
        const CONFIG_DIRECTORY_ENV_VAR: &str = "AZIOT_EDGED_CONFIG_DIR";
        const CONFIG_DIRECTORY_DEFAULT: &str = "/etc/aziot/edged/config.d";

        let config_path: std::path::PathBuf =
            std::env::var_os(CONFIG_ENV_VAR).map_or_else(|| CONFIG_FILE_DEFAULT.into(), Into::into);

        let config_directory_path: std::path::PathBuf = std::env::var_os(CONFIG_DIRECTORY_ENV_VAR)
            .map_or_else(|| CONFIG_DIRECTORY_DEFAULT.into(), Into::into);

        let settings: Settings =
            config_common::read_config(&config_path, Some(&config_directory_path))
                .map_err(|err| LoadSettingsError(Context::new(Box::new(err))))?;

        Ok(settings)
    }

    pub fn with_device_id(mut self, device_id: &str) -> Self {
        self.device_id = Some(device_id.to_owned());
        self
    }

    pub fn with_iot_hub_hostname(mut self, iot_hub_hostname: &str) -> Self {
        self.iot_hub_hostname = Some(iot_hub_hostname.to_owned());
        self
    }

    pub fn with_nodes_rbac(mut self, has_nodes_rbac: bool) -> Self {
        self.has_nodes_rbac = has_nodes_rbac;
        self
    }

    pub fn namespace(&self) -> &str {
        &self.namespace
    }

    pub fn iot_hub_hostname(&self) -> Option<&str> {
        self.iot_hub_hostname.as_deref()
    }

    pub fn proxy(&self) -> &ProxySettings {
        &self.proxy
    }

    pub fn device_id(&self) -> Option<&str> {
        self.device_id.as_deref()
    }

    pub fn device_hub_selector(&self) -> &str {
        &self.device_hub_selector
    }
    pub fn config_path(&self) -> &str {
        &self.config_path
    }

    pub fn config_map_name(&self) -> &str {
        &self.config_map_name
    }

    pub fn config_map_volume(&self) -> &str {
        &self.config_map_volume
    }

    pub fn resources(&self) -> Option<&ResourceRequirements> {
        self.resources.as_ref()
    }

    pub fn has_nodes_rbac(&self) -> bool {
        self.has_nodes_rbac
    }

    fn default_nodes_rbac() -> bool {
        true
    }
}

impl RuntimeSettings for Settings {
    type Config = DockerConfig;

    fn agent(&self) -> &ModuleSpec<DockerConfig> {
        self.base.agent()
    }

    fn agent_mut(&mut self) -> &mut ModuleSpec<DockerConfig> {
        self.base.agent_mut()
    }

    fn hostname(&self) -> &str {
        self.base.hostname()
    }

    fn connect(&self) -> &Connect {
        self.base.connect()
    }

    fn listen(&self) -> &Listen {
        self.base.listen()
    }

    fn homedir(&self) -> &Path {
        self.base.homedir()
    }

    fn watchdog(&self) -> &WatchdogSettings {
        self.base.watchdog()
    }

    fn endpoints(&self) -> &Endpoints {
        self.base.endpoints()
    }

    fn edge_ca_cert(&self) -> Option<&str> {
        self.base.edge_ca_cert()
    }

    fn edge_ca_key(&self) -> Option<&str> {
        self.base.edge_ca_key()
    }

    fn trust_bundle_cert(&self) -> Option<&str> {
        self.base.trust_bundle_cert()
    }

    fn auto_reprovisioning_mode(&self) -> &AutoReprovisioningMode {
        self.base.auto_reprovisioning_mode()
    }
}

#[derive(Clone, Debug, serde_derive::Deserialize, serde_derive::Serialize)]
pub struct ProxySettings {
    auth: Option<AuthConfig>,
    image: String,
    image_pull_policy: String,
    config_path: String,
    config_map_name: String,
    trust_bundle_path: String,
    trust_bundle_config_map_name: String,
    resources: Option<ResourceRequirements>,
}

impl ProxySettings {
    pub fn auth(&self) -> Option<&AuthConfig> {
        self.auth.as_ref()
    }

    pub fn image(&self) -> &str {
        &self.image
    }

    pub fn config_path(&self) -> &str {
        &self.config_path
    }

    pub fn config_map_name(&self) -> &str {
        &self.config_map_name
    }

    pub fn trust_bundle_path(&self) -> &str {
        &self.trust_bundle_path
    }

    pub fn trust_bundle_config_map_name(&self) -> &str {
        &self.trust_bundle_config_map_name
    }

    pub fn image_pull_policy(&self) -> &str {
        &self.image_pull_policy
    }

    pub fn resources(&self) -> Option<&ResourceRequirements> {
        self.resources.as_ref()
    }
}

#[derive(Debug, Fail)]
#[fail(display = "Could not load settings")]
pub struct LoadSettingsError(#[cause] Context<Box<dyn std::fmt::Display + Send + Sync>>);

impl From<std::io::Error> for LoadSettingsError {
    fn from(err: std::io::Error) -> Self {
        LoadSettingsError(Context::new(Box::new(err)))
    }
}

impl From<serde_json::Error> for LoadSettingsError {
    fn from(err: serde_json::Error) -> Self {
        LoadSettingsError(Context::new(Box::new(err)))
    }
}

impl From<Error> for LoadSettingsError {
    fn from(err: Error) -> Self {
        LoadSettingsError(Context::new(Box::new(err)))
    }
}

impl From<Context<ErrorKind>> for LoadSettingsError {
    fn from(inner: Context<ErrorKind>) -> Self {
        From::from(Error::from(inner))
    }
}

impl From<ErrorKind> for LoadSettingsError {
    fn from(kind: ErrorKind) -> Self {
        From::from(Error::from(kind))
    }
}