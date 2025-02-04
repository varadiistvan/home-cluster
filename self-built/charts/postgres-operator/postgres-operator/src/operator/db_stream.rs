use base64::prelude::*;
use futures::StreamExt as _;
use k8s_openapi::api::core::v1::Secret;
use kube::{
    api::WatchEvent,
    runtime::{watcher, WatchStreamExt},
    Api,
};

use crate::crds::{
    AdminCredentials, PostgresDatabase, PostgresDatabaseSpec, PostgresInstance, SecretRef,
    SpecDatabase,
};

pub async fn database_crd_created(db: PostgresDatabase, secret_api: &Api<Secret>) {
    let PostgresDatabase {
        metadata: _,
        spec:
            PostgresDatabaseSpec {
                database:
                    SpecDatabase {
                        db_name,
                        owner,
                        extensions,
                    },
                instance:
                    PostgresInstance {
                        host,
                        port,
                        admin_credentials:
                            AdminCredentials {
                                username,
                                secret_ref:
                                    SecretRef {
                                        name,
                                        username_key,
                                        password_key,
                                    },
                            },
                    },
            },
    } = db;

    if username.is_none() && username_key.is_none() {
        tracing::error!("Username or username_key is required");
        return;
    }
    let secret = secret_api.get(&name).await;
    if secret.is_err() {
        tracing::error!("Failed to get secret: {name}");
        return;
    }
    let secret_data = secret.unwrap().data;
    if secret_data.is_none() {
        tracing::error!("Secret {name} has no data");
        return;
    }
    let secret_data = secret_data.unwrap();
    if !secret_data.contains_key(&password_key) {
        tracing::error!("Secret {name} has no password key");
        return;
    }
    let username = if username_key.is_none() {
        username.unwrap()
    } else {
        let i = BASE64_STANDARD.decode(&secret_data.get(&username_key.unwrap()).unwrap().0);
        if i.is_err() {
            tracing::error!("Failed to decode username");
            return;
        }
        if let Ok(rat) = String::from_utf8(i.unwrap()) {
            rat
        } else {
            tracing::error!("Failed to convert username to string");
            return;
        }
    };

    let password = super::get_string_value_from_secret(&password_key, secret_api, &name).await;

    if password.is_err() {
        tracing::error!("{password:?}")
    }

    let password = password.unwrap();

    let connection_string = format!(
        "host={} port={} dbname={} user={} password={}",
        host,
        port.unwrap_or(5432),
        db_name,
        username,
        password
    );
    let mut config = tokio_postgres::Config::new();
    config.user(&username);
    config.password(&password);
    config.host(&host);
    config.port(port.unwrap_or(5432));

    if let Ok((mut client, connection)) = config.connect(tokio_postgres::NoTls).await {
        tokio::spawn(async move {
            if let Err(e) = connection.await {
                tracing::error!("{e:?}");
            }
        });

        let create_res = super::create_db(
            &mut client,
            db_name,
            owner,
            &extensions.unwrap_or_default(),
            &mut config,
        )
        .await;
        if create_res.is_err() {
            tracing::error!("{create_res:?}");
        }
    } else {
        tracing::error!(
            "Failed to connect to database with connection string: {connection_string}"
        );
    }
}

pub async fn handle_database_stream(
    postgresdatabase_api: Api<PostgresDatabase>,
    secret_api: &Api<Secret>,
) {
    let mut db_stream = watcher(postgresdatabase_api, Default::default())
        .default_backoff()
        .applied_objects()
        .boxed();

    while let Some(status) = db_stream.next().await {
        if let Ok(db) = status {
            tracing::info!("Got request for database: {db:?}");
            database_crd_created(db, secret_api).await;
        } else {
            tracing::error!("{status:?}");
        }
    }
}
