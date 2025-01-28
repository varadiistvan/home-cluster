use anyhow::{Context, Result};
use futures::StreamExt;
use k8s_openapi::api::core::v1::Secret;
use kube::{Api, Client, CustomResource, ResourceExt};
use schemars::JsonSchema;
use serde::{Deserialize, Serialize};
use tokio_postgres::{Client as PgClient, NoTls};

mod crds;
mod operator;

#[tokio::main]
async fn main() -> Result<()> {
    let client = Client::try_default()
        .await
        .context("Failed to create K8s client")?;

    let subscriber = tracing_subscriber::FmtSubscriber::builder()
        .with_max_level(tracing::Level::DEBUG)
        .finish();

    tracing::subscriber::set_global_default(subscriber).context("Failed to set subscriber")?;

    loop {}
}
