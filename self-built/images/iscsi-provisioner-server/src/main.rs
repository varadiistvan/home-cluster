use axum::Router;
use std::{env, net::SocketAddr, process::Command};
use tower::ServiceBuilder;
use tower_http::compression::CompressionLayer;

mod iscsi;
mod models;
mod v1;

// Read the base path for LUNs from environment variable, with a default value
fn get_lun_base_path() -> String {
    env::var("LUN_BASE_PATH").unwrap_or_else(|_| "/var/lib/iscsi/luns".to_string())
}

#[tokio::main]
async fn main() {
    env::var("ISCSI_PWD").expect("ISCSI_PWD env variable is required");

    Command::new("tgtadm")
        .output()
        .expect("tgtadm is required to be installed");

    Command::new("qemu-img")
        .output()
        .expect("qemu-img is required to be installed");

    let app = Router::new()
        .nest("/api/v1/", v1::get_routes())
        .layer(ServiceBuilder::new().layer(CompressionLayer::new()));

    let port: u16 = env::var("ISCSI_PORT")
        .map(|p| p.parse())
        .unwrap_or(Ok(3000))
        .expect("ISCSI_PORT should be a valid port");
    let addr = SocketAddr::from(([0, 0, 0, 0], port));
    let listener = tokio::net::TcpListener::bind(addr).await.unwrap();
    println!("Listening on {}", addr);

    axum::serve(listener, app.into_make_service())
        .await
        .unwrap();
}
