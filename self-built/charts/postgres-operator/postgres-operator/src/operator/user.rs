use postgres_protocol::escape::{self, escape_literal};
use thiserror::Error;

#[derive(Debug, Error)]
pub enum UserError {
    #[error("{0}")]
    PostgresError(tokio_postgres::Error),
}

pub async fn create_user(
    connection: &mut tokio_postgres::Client,
    username: String,
    password: String,
    privileges: &[String],
) -> Result<(), UserError> {
    tracing::info!("Running queries for user {username}");

    let tr = connection
        .transaction()
        .await
        .map_err(UserError::PostgresError)?;

    let user_in_db = tr
        .query_opt(
            "SELECT usename FROM pg_user WHERE usename = $1",
            &[&username],
        )
        .await
        .map_err(UserError::PostgresError)?;

    if user_in_db.is_none() {
        tr.execute(
            &format!(
                "CREATE USER {} WITH PASSWORD {}",
                escape::escape_identifier(&username),
                escape_literal(&password)
            ),
            &[],
        )
        .await
        .map_err(UserError::PostgresError)?;
    } else {
        tr.execute(
            &format!(
                "ALTER USER {} WITH PASSWORD {}",
                escape::escape_identifier(&username),
                escape::escape_literal(&password)
            ),
            &[],
        )
        .await
        .map_err(UserError::PostgresError)?;
    }

    const PRIVILEGES: [&str; 5] = [
        "SUPERUSER",
        "CREATEDB",
        "CREATEROLE",
        "REPLICATION",
        "BYPASSRLS",
    ];

    for privilege in privileges {
        if !PRIVILEGES.contains(&privilege.as_str()) {
            tracing::error!("Invalid privilege: {privilege}");
        } else {
            let add_err = tr
                .execute(
                    &format!(
                        "ALTER USER {} WITH {}",
                        escape::escape_identifier(&username),
                        privilege
                    ),
                    &[],
                )
                .await;
            if add_err.is_err() {
                tracing::error!(
                    "Failed to add privilege: {privilege} for user {username}: ${:?}",
                    add_err
                )
            }
        }
    }

    let res = tr.commit().await.map_err(UserError::PostgresError);
    if res.is_ok() {
        tracing::info!("User {username} created/updated");
    };

    res
}
