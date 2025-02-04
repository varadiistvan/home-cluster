use postgres_protocol::escape;
use thiserror::Error;
use tokio_postgres::Config;

#[derive(Debug, Error)]
pub enum DatabaseError {
    #[error("User not found for database")]
    UserNotFound,
    #[error("Postgres errror: \n error: {0}")]
    Other(tokio_postgres::Error),
}

pub async fn create_db(
    connection: &mut tokio_postgres::Client,
    db_name: String,
    db_owner: String,
    extensions: &[String],
    config: &mut Config,
) -> Result<(), DatabaseError> {
    tracing::info!("Running queries for database {db_name}");

    let owner_res = connection
        .query_opt(
            "SELECT usename FROM pg_user WHERE usename = $1",
            &[&db_owner],
        )
        .await
        .map_err(DatabaseError::Other)?;

    if owner_res.is_none() {
        return Err(DatabaseError::UserNotFound);
    }

    let existing_database = connection
        .query_opt(
            "SELECT datname FROM pg_database WHERE datname = $1",
            &[&db_name],
        )
        .await
        .map_err(DatabaseError::Other)?;

    if existing_database.is_none() {
        connection
            .execute(
                &format!("CREATE DATABASE {}", escape::escape_identifier(&db_name)),
                &[],
            )
            .await
            .map_err(DatabaseError::Other)?;
    }

    config.dbname(&db_name);

    let (mut connection, actual_connection) = config
        .connect(tokio_postgres::NoTls)
        .await
        .map_err(DatabaseError::Other)?;

    tokio::spawn(async move {
        if let Err(e) = actual_connection.await {
            tracing::error!("{e:?}");
        }
    });

    let tr = connection
        .transaction()
        .await
        .map_err(DatabaseError::Other)?;

    tr.execute(
        &format!(
            "ALTER DATABASE {} OWNER TO {}",
            escape::escape_identifier(&db_name),
            escape::escape_identifier(&db_owner)
        ),
        &[],
    )
    .await
    .map_err(DatabaseError::Other)?;

    tr.execute(
        &format!(
            "GRANT ALL PRIVILEGES ON DATABASE {} TO {}",
            escape::escape_identifier(&db_name),
            escape::escape_identifier(&db_owner)
        ),
        &[],
    )
    .await
    .map_err(DatabaseError::Other)?;

    for extension in extensions {
        let res = tr
            .execute(
                &format!(
                    "CREATE EXTENSION IF NOT EXISTS {} CASCADE",
                    escape::escape_identifier(extension)
                ),
                &[],
            )
            .await
            .map_err(DatabaseError::Other);
        if res.is_err() {
            tracing::error!(
                "Failed to create extension {}: {}",
                extension,
                res.unwrap_err()
            );
        }
    }

    let res = tr.commit().await.map_err(DatabaseError::Other);
    if res.is_ok() {
        tracing::info!("Database {db_name} created/updated");
    };

    res
}
