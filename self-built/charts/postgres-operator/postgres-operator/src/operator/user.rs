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

    // let tr = connection
    //     .transaction()
    //     .await
    //     .map_err(UserError::PostgresError)?;

    let tr = connection;

    let user_in_db: Option<String> = tr
        .query_one("SELECT 1 FROM pg_user WHERE usename = $1", &[&username])
        .await
        .map_err(UserError::PostgresError)?
        .get(0);

    if user_in_db.is_none() {
        tr.execute("CREATE USER $1 WITH PASSWORD $2", &[&username, &password])
            .await
            .map_err(UserError::PostgresError)?;
    } else {
        tr.execute("ALTER USER $1 WITH PASSWORD $2", &[&username, &password])
            .await
            .map_err(UserError::PostgresError)?;
    }

    let privileges_futures = privileges.iter().map(|privilege| async {
        let privilege = privilege.clone();
        (
            tr.execute(
                "GRANT $1 ON ALL TABLES IN SCHEMA public TO $2",
                &[&privilege, &username],
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

    // let res = tr.commit().await.map_err(UserError::PostgresError);
    // if res.is_ok() {
    //     tracing::info!("User {username} created/updated");
    // };
    //
    // res
    Ok(())
}
