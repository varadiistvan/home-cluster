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
        .query("SELECT 1 FROM pg_user WHERE usename = $1", &[&username])
        .await
        .map_err(UserError::PostgresError)?;

    if user_in_db.is_empty() {
        tr.execute(
            &format!("CREATE USER pg_catalog.quote_indent('{username}') WITH PASSWORD $1"),
            &[&password],
        )
        .await
        .map_err(UserError::PostgresError)?;
    } else {
        tr.execute(
            &format!("ALTER USER pg_catalog.quote_indent('{username}') WITH PASSWORD $1"),
            &[&password],
        )
        .await
        .map_err(UserError::PostgresError)?;
    }

    let privileges_futures = privileges.iter().map(|privilege| async {
        let privilege = privilege.clone();
        (
            tr.execute(
                &format!("GRANT pg_catalog.quote_indent('{privilege}') ON ALL TABLES IN SCHEMA public TO pg_catalog.quote_indent('{username}')"),
                &[],
            )
            .await,
            privilege,
        )
    });

    futures::future::join_all(privileges_futures)
        .await
        .into_iter()
        .for_each(|(res, privilege)| {
            if let Err(e) = res {
                tracing::error!(
                    "Failed to add privilege: {privilege} for user {username}: ${:?}",
                    e
                )
            }
        });

    let res = tr.commit().await.map_err(UserError::PostgresError);
    if res.is_ok() {
        tracing::info!("User {username} created/updated");
    };

    res
}
