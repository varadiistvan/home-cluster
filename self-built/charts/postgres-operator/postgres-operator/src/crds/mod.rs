mod postgresdatabase;
mod postgresuser;

pub use postgresdatabase::*;
pub use postgresuser::*;

use schemars::JsonSchema;
use serde::{Deserialize, Serialize};

#[derive(Serialize, Deserialize, Debug, Clone, PartialEq, JsonSchema)]
pub struct PostgresInstance {
    pub host: String,
    pub port: Option<u16>,
    #[serde(rename = "adminCredentials")]
    pub admin_credentials: AdminCredentials,
}

#[derive(Serialize, Deserialize, Debug, Clone, PartialEq, JsonSchema)]
pub struct AdminCredentials {
    #[serde(rename = "secretRef")]
    pub secret_ref: SecretRef,
    pub username: Option<String>,
}

#[derive(Serialize, Deserialize, Debug, Clone, PartialEq, JsonSchema)]
pub struct SecretRef {
    pub name: String,
    #[serde(rename = "usernameKey")]
    pub username_key: Option<String>,
    #[serde(rename = "passwordKey")]
    pub password_key: String,
}
