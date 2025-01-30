use base64::prelude::*;
use futures::StreamExt as _;
use k8s_openapi::api::core::v1::Secret;
use kube::{
    api::WatchEvent,
    runtime::{watcher, WatchStreamExt},
    Api,
};

use crate::crds::{
    AdminCredentials, PostgresDatabase, PostgresDatabaseSpec, PostgresInstance, PostgresUser,
    PostgresUserSpec, SecretRef, SpecDatabase, SpecUser, UserPasswordSecretRef,
};

pub async fn user_crd_created(user: PostgresUser, secret_api: &Api<Secret>) {
    let PostgresUser {
        metadata: _,
        spec:
            PostgresUserSpec {
                user:
                    SpecUser {
                        privileges,
                        secret_ref:
                            UserPasswordSecretRef {
                                name,
                                key: password_key,
                            },
                        username,
                    },
                instance:
                    PostgresInstance {
                        host,
                        port,
                        admin_credentials:
                            AdminCredentials {
                                username: admin_username,
                                secret_ref:
                                    SecretRef {
                                        name: admin_secret_name,
                                        username_key: admin_username_key,
                                        password_key: admin_password_key,
                                    },
                            },
                    },
            },
    } = user;

    if admin_username.is_none() && admin_username_key.is_none() {
        tracing::error!("Username or username_key is required");
        return;
    }
    let admin_secret = secret_api.get(&admin_secret_name).await;
    if admin_secret.is_err() {
        tracing::error!("Failed to get secret: {name}");
        return;
    }
    let admin_secret_data = admin_secret.unwrap().data;
    if admin_secret_data.is_none() {
        tracing::error!("Secret {name} has no data");
        return;
    }
    let admin_secret_data = admin_secret_data.unwrap();
    if !admin_secret_data.contains_key(&admin_password_key) {
        tracing::error!("Secret {name} has no password key");
        return;
    }
    let admin_username = if admin_username_key.is_none() {
        admin_username.unwrap()
    } else {
        let i = BASE64_STANDARD.decode(
            &admin_secret_data
                .get(&admin_username_key.unwrap())
                .unwrap()
                .0,
        );
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

    let admin_password =
        super::get_string_value_from_secret(&admin_password_key, secret_api, &admin_secret_name)
            .await;

    if admin_password.is_err() {
        tracing::error!("{admin_password:?}")
    }

    let admin_password = admin_password.unwrap();

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

    let password = super::get_string_value_from_secret(&password_key, secret_api, &name).await;

    if password.is_err() {
        tracing::error!("{password:?}")
    }
    let password = password.unwrap();

    let connection_string = format!(
        "host={} port={} username={} password={}",
        host,
        port.unwrap_or(5432),
        admin_username,
        admin_password,
    );

    let mut config = tokio_postgres::Config::new();
    config.user(&admin_username);
    config.password(&admin_password);
    config.host(&host);
    config.port(port.unwrap_or(5432));

    if let Ok((mut client, connection)) = config.connect(tokio_postgres::NoTls).await {
        tokio::spawn(async move {
            if let Err(e) = connection.await {
                tracing::error!("{e:?}");
            }
        });
        let create_res = super::create_user(
            &mut client,
            username,
            password,
            &privileges.unwrap_or_default(),
        )
        .await;
        if create_res.is_err() {
            tracing::error!("{create_res:?}");
        }
    } else {
        tracing::error!("Failed to connect to database with string: {connection_string}");
    }
}

pub async fn handle_user_stream(postgresuser_api: Api<PostgresUser>, secret_api: &Api<Secret>) {
    let mut user_stream = watcher(postgresuser_api, Default::default())
        .default_backoff()
        .applied_objects()
        .boxed();

    while let Some(status) = user_stream.next().await {
        if let Ok(user) = status {
            tracing::info!("Got request for user: {user:?}");
            user_crd_created(user, secret_api).await;
        } else {
            tracing::error!("{status:?}");
        }
    }
}
