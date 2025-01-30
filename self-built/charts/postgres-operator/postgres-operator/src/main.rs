use std::sync::Arc;

use anyhow::{Context, Result};
use base64::prelude::*;
use crds::{PostgresDatabase, PostgresUser};
use kube::{Api, Client};

mod crds;
mod operator;

#[tokio::main]
async fn main() -> Result<()> {
    let k8s_client = Client::try_default()
        .await
        .context("Failed to create K8s client")?;

    let subscriber = tracing_subscriber::FmtSubscriber::builder()
        .with_max_level(tracing::Level::INFO)
        .finish();

    tracing::subscriber::set_global_default(subscriber).context("Failed to set subscriber")?;

    let posgresuser_api: Api<PostgresUser> = Api::default_namespaced(k8s_client.clone());
    let postgresdatabase_api: Api<PostgresDatabase> = Api::default_namespaced(k8s_client.clone());
    let secret_api: Api<k8s_openapi::api::core::v1::Secret> =
        Api::default_namespaced(k8s_client.clone());

    let secret_api_clone = secret_api.clone();
    let postgresdatabase_api_clone = postgresdatabase_api.clone();
    let dat = tokio::spawn(async move {
        operator::handle_database_stream(postgresdatabase_api_clone, &secret_api_clone).await
    });

    let secret_api_clone = secret_api.clone();
    let posgresuser_api_clone = posgresuser_api.clone();
    let us = tokio::spawn(async move {
        operator::handle_user_stream(posgresuser_api_clone, &secret_api_clone).await
    });

    let sec = tokio::spawn(async move {
        operator::handle_secret_stream(secret_api, &posgresuser_api, &postgresdatabase_api).await;
    });

    let (a, b, c) = tokio::join!(dat, us, sec);

    if a.is_err() {
        tracing::error!("{a:?}");
    }
    if b.is_err() {
        tracing::error!("{b:?}");
    }

    if c.is_err() {
        tracing::error!("{c:?}");
    }

    Ok(())
}
