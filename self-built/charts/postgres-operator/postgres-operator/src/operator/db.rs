use thiserror::Error;

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
) -> Result<(), DatabaseError> {
    tracing::info!("Running queries for database {db_name}");

    let tr = connection
        .transaction()
        .await
        .map_err(DatabaseError::Other)?;

    let owner_res = tr
        .query_one(
            "SELECT usename FROM pg_user WHERE usename = $1",
            &[&db_owner],
        )
        .await
        .map_err(DatabaseError::Other)?;

    if owner_res.is_empty() {
        return Err(DatabaseError::UserNotFound);
    }

    let existing_database = tr
        .query_one(
            "SELECT datname FROM pg_database WHERE datname = $1",
            &[&db_name],
        )
        .await
        .map_err(DatabaseError::Other)?;

    if existing_database.is_empty() {
        tr.execute("CREATE DATABASE $1", &[&db_name])
            .await
            .map_err(DatabaseError::Other)?;
    }

    tr.execute("ALTER DATABASE $1 OWNER TO $2", &[&db_name, &db_owner])
        .await
        .map_err(DatabaseError::Other)?;

    tr.execute(
        "GRANT ALL PRIVILEGES ON DATABASE $1 TO $2",
        &[&db_name, &db_owner],
    )
    .await
    .map_err(DatabaseError::Other)?;

    let extension_futures = extensions.iter().map(|ext| async {
        let ext = ext.clone();
        (
            tr.execute("CREATE EXTENSION IF NOT EXISTS $1", &[&ext])
                .await
                .map_err(DatabaseError::Other),
            ext,
        )
    });

    futures::future::join_all(extension_futures)
        .await
        .into_iter()
        .for_each(|(res, ext)| {
            if let Err(e) = res {
                tracing::error!("Failed to create extension {}: {}", ext, e);
            }
        });

    let res = tr.commit().await.map_err(DatabaseError::Other);
    if res.is_ok() {
        tracing::info!("Database {db_name} created/updated");
    };

    res
}
