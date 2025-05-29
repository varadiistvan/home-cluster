use clap::Parser;
use config::{Config, Environment, File};
use serde::Deserialize;
use std::fs;
use std::process::Command;
use tonic::metadata::{MetadataMap, MetadataValue};
use tonic::Request as TonicRequest;
use tonic::{transport::Server, Request, Response, Status};
use zfs::zfs_service_server::{ZfsService, ZfsServiceServer};
use zfs::{
    CreateZvolRequest, CreateZvolResponse, DeleteZvolRequest, DeleteZvolResponse,
    ResizeZvolRequest, ResizeZvolResponse,
};

mod zfs {
    tonic::include_proto!("zfs");
}

#[derive(Debug)]
enum ZfsError {
    CommandFailed(String),
    AuthenticationFailed,
}

impl From<ZfsError> for Status {
    fn from(err: ZfsError) -> Self {
        match err {
            ZfsError::CommandFailed(msg) => Status::internal(msg),
            ZfsError::AuthenticationFailed => {
                Status::unauthenticated("Invalid or missing authentication token")
            }
        }
    }
}

/// Configuration struct from config file and environment variables
#[derive(Debug, Deserialize)]
struct Settings {
    zpool_name: String,
    iscsi_target: String,
    auth_token: String,
}

/// CLI Arguments
#[derive(Parser)]
#[clap(version = "1.0", about = "ZFS + iSCSI NAS Server")]
struct Args {
    #[clap(short, long, default_value = "config.yaml")]
    config: String,
}

#[derive(Debug)]
pub struct ZfsServer {
    settings: Settings,
}

impl ZfsServer {
    fn authenticate(&self, metadata: &MetadataMap) -> Result<(), ZfsError> {
        let token = self.settings.auth_token.clone();
        match metadata.get("authorization") {
            Some(value) if value == token.as_str() => Ok(()),
            _ => Err(ZfsError::AuthenticationFailed),
        }
    }
}

#[tonic::async_trait]
impl ZfsService for ZfsServer {
    async fn create_zvol(
        &self,
        request: Request<CreateZvolRequest>,
    ) -> Result<Response<CreateZvolResponse>, Status> {
        self.authenticate(request.metadata())
            .map_err(Status::from)?;
        let req = request.into_inner();
        let zvol_path = format!("{}/{}", self.settings.zpool_name, req.name);

        let output = Command::new("zfs")
            .arg("create")
            .arg("-V")
            .arg(req.size)
            .arg(&zvol_path)
            .output()
            .map_err(|e| {
                ZfsError::CommandFailed(format!("Failed to execute zfs command: {}", e))
            })?;

        if output.status.success() {
            Ok(Response::new(CreateZvolResponse {
                success: true,
                message: format!("ZVOL {} created", zvol_path),
            }))
        } else {
            Err(ZfsError::CommandFailed(String::from_utf8_lossy(&output.stderr).to_string()).into())
        }
    }

    async fn delete_zvol(
        &self,
        request: Request<DeleteZvolRequest>,
    ) -> Result<Response<DeleteZvolResponse>, Status> {
        self.authenticate(request.metadata())
            .map_err(Status::from)?;
        let req = request.into_inner();
        let zvol_path = format!("{}/{}", self.settings.zpool_name, req.name);

        let output = Command::new("zfs")
            .arg("destroy")
            .arg(&zvol_path)
            .output()
            .map_err(|e| {
                ZfsError::CommandFailed(format!("Failed to execute zfs command: {}", e))
            })?;

        if output.status.success() {
            Ok(Response::new(DeleteZvolResponse {
                success: true,
                message: format!("ZVOL {} deleted", zvol_path),
            }))
        } else {
            Err(ZfsError::CommandFailed(String::from_utf8_lossy(&output.stderr).to_string()).into())
        }
    }

    async fn resize_zvol(
        &self,
        request: Request<ResizeZvolRequest>,
    ) -> Result<Response<ResizeZvolResponse>, Status> {
        self.authenticate(request.metadata())
            .map_err(Status::from)?;
        let req = request.into_inner();
        let zvol_path = format!("{}/{}", self.settings.zpool_name, req.name);

        let output = Command::new("zfs")
            .arg("set")
            .arg(format!("volsize={}", req.new_size))
            .arg(&zvol_path)
            .output()
            .map_err(|e| {
                ZfsError::CommandFailed(format!("Failed to execute zfs command: {}", e))
            })?;

        if output.status.success() {
            Ok(Response::new(ResizeZvolResponse {
                success: true,
                message: format!("ZVOL {} resized to {}", zvol_path, req.new_size),
            }))
        } else {
            Err(ZfsError::CommandFailed(String::from_utf8_lossy(&output.stderr).to_string()).into())
        }
    }
}

#[tokio::main]
async fn main() -> Result<(), Box<dyn std::error::Error>> {
    let args = Args::parse();

    let settings = Config::builder()
        .add_source(File::with_name(&args.config))
        .add_source(Environment::with_prefix("ZFS"))
        .build()?
        .try_deserialize::<Settings>()?;

    let addr = "[::1]:50051".parse()?;
    let zfs_service = ZfsServer { settings };

    println!("Starting ZFS gRPC server at {}", addr);
    Server::builder()
        .add_service(ZfsServiceServer::new(zfs_service))
        .serve(addr)
        .await?;

    Ok(())
}
