use thiserror::Error;

#[derive(Debug, Error)]
pub enum UserError {
    #[error("{0}")]
    PostgresError(tokio_postgres::Error),
}
