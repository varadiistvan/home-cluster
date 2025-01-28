use kube::CustomResource;
use schemars::JsonSchema;
use serde::{Deserialize, Serialize};

use super::PostgresInstance;

#[derive(CustomResource, Serialize, Debug, Deserialize, Clone, PartialEq, JsonSchema)]
#[kube(
    group = "stevevaradi.me",
    version = "v1",
    kind = "PostgresDatabase",
    namespaced
)]
pub struct PostgresDatabaseSpec {
    pub instance: PostgresInstance,
    pub database: SpecDatabase,
}

#[derive(Serialize, Deserialize, Debug, Clone, PartialEq, JsonSchema)]
pub struct SpecDatabase {
    pub db_name: String,
    pub owner: String,
    pub extensions: Option<Vec<String>>,
}
