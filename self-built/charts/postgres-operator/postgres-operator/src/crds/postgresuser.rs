use super::{PostgresInstance, SecretRef};
use kube::CustomResource;
use schemars::JsonSchema;
use serde::{Deserialize, Serialize};

#[derive(CustomResource, Debug, Serialize, Deserialize, Clone, PartialEq, JsonSchema)]
#[kube(
    group = "stevevaradi.me",
    version = "v1",
    kind = "PostgresUser",
    namespaced
)]
pub struct PostgresUserSpec {
    pub instance: PostgresInstance,
    pub user: SpecUser,
}

#[derive(Serialize, Deserialize, Debug, Clone, PartialEq, JsonSchema)]
pub struct SpecUser {
    pub username: Option<String>,
    pub password_secret: SecretRef,
    pub privileges: Option<Vec<String>>,
}
