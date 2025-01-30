use std::sync::Arc;

use futures::StreamExt as _;
use k8s_openapi::api::core::v1::Secret;
use kube::{
    api::WatchEvent,
    runtime::{watcher, WatchStreamExt},
    Api,
};

use crate::crds::{PostgresDatabase, PostgresUser};

pub async fn handle_secret_stream(
    secret_api: Api<Secret>,
    postgresuser_api: &Api<PostgresUser>,
    postgresdatabase_api: &Api<PostgresDatabase>,
) -> () {
    let secret_api_clone = secret_api.clone();
    let mut secret_stream = watcher(secret_api_clone, Default::default())
        .default_backoff()
        .applied_objects()
        .boxed();

    while let Some(status) = secret_stream.next().await {
        if let Ok(secret) = status {
            let postgresusers = postgresuser_api.list(&Default::default()).await;
            if postgresusers.is_err() {
                tracing::error!("{postgresusers:?}");
            }
            let postgresusers = postgresusers.unwrap();

            let postgresdatabases = postgresdatabase_api.list(&Default::default()).await;
            if postgresdatabases.is_err() {
                tracing::error!("{postgresdatabases:?}");
            }
            let postgresdatabases = postgresdatabases.unwrap();

            let secret_name = secret.metadata.name.clone().unwrap();

            let user_promises = postgresusers
                .items
                .into_iter()
                .filter(|user| {
                    user.spec.user.secret_ref.name == secret_name
                        || user.spec.instance.admin_credentials.secret_ref.name == secret_name
                })
                .map(|user| async {
                    tracing::info!(
                        "Refreshing user {user:?} since secret {secret_name} was changed"
                    );
                    super::user_crd_created(user, &secret_api).await
                });

            let database_promises = postgresdatabases
                .items
                .into_iter()
                .filter(|database| {
                    database.spec.instance.admin_credentials.secret_ref.name == secret_name
                })
                .map(|database| async {
                    tracing::info!(
                        "Refreshing db {database:?} since secret {secret_name} was changed"
                    );
                    super::database_crd_created(database, &secret_api).await
                });

            futures::future::join_all(user_promises).await;
            futures::future::join_all(database_promises).await;
        } else {
            tracing::error!("{status:?}");
        }
    }
}
