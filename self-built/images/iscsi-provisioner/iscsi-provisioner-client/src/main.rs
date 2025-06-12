use std::collections::HashMap;
use clap::Parser;
use reqwest::Client;
use serde::Serialize;
use tonic::{Request, Response, Status};

mod csi {
    tonic::include_proto!("csi.v1");
}

use csi::identity_server::Identity;
use crate::csi::{plugin_capability::{Type as PluginCapabilityType, Service as PluginService}, ControllerExpandVolumeRequest, ControllerExpandVolumeResponse, ControllerGetCapabilitiesRequest, ControllerGetCapabilitiesResponse, ControllerGetVolumeRequest, ControllerGetVolumeResponse, ControllerModifyVolumeRequest, ControllerModifyVolumeResponse, ControllerPublishVolumeRequest, ControllerPublishVolumeResponse, ControllerUnpublishVolumeRequest, ControllerUnpublishVolumeResponse, CreateSnapshotRequest, CreateSnapshotResponse, CreateVolumeRequest, CreateVolumeResponse, DeleteSnapshotRequest, DeleteSnapshotResponse, DeleteVolumeRequest, DeleteVolumeResponse, GetCapacityRequest, GetCapacityResponse, GetPluginCapabilitiesRequest, GetPluginCapabilitiesResponse, GetPluginInfoRequest, GetPluginInfoResponse, GetSnapshotRequest, GetSnapshotResponse, ListSnapshotsRequest, ListSnapshotsResponse, ListVolumesRequest, ListVolumesResponse, PluginCapability, ProbeRequest, ProbeResponse, ValidateVolumeCapabilitiesRequest, ValidateVolumeCapabilitiesResponse, Volume};
use crate::csi::controller_server::Controller;
use crate::csi::plugin_capability::service::Type::ControllerService;
use crate::csi::plugin_capability::Type::{Service as ServiceType, VolumeExpansion as VolumeExpansionType};
use crate::csi::plugin_capability::volume_expansion::Type::Offline;
use crate::csi::plugin_capability::{Service, VolumeExpansion};

#[derive(Clone)]
struct ISCSIProvisioner {
    client: Client,
    api_url: String,
    bearer: String,
    driver_name: String,
    driver_version: String,
}

#[tonic::async_trait    ]
impl Identity for ISCSIProvisioner {
    async fn get_plugin_info(&self, request: Request<GetPluginInfoRequest>) -> Result<Response<GetPluginInfoResponse>, Status> {
        Ok(Response::new(GetPluginInfoResponse {
            name: self.driver_name.clone(),
            vendor_version: self.driver_version.clone(),
            manifest: HashMap::new(),
        }))
    }

    async fn get_plugin_capabilities(&self, request: Request<GetPluginCapabilitiesRequest>) -> Result<Response<GetPluginCapabilitiesResponse>, Status> {
        let caps = vec![PluginCapability {
            r#type: Some(VolumeExpansionType(VolumeExpansion { r#type: i32::from(Offline) })),
        }, PluginCapability { r#type: Some(ServiceType(Service{ r#type: i32::from(ControllerService) })) }];
        Ok(Response::new(GetPluginCapabilitiesResponse { capabilities: caps }))
    }

    async fn probe(&self, request: Request<ProbeRequest>) -> Result<Response<ProbeResponse>, Status> {
        Ok(Response::new(ProbeResponse { ready: Some(true) }))
    }
}

impl Controller for ISCSIProvisioner {
    async fn create_volume(&self, request: Request<CreateVolumeRequest>) -> Result<Response<CreateVolumeResponse>, Status> {
        let req = req.into_inner();
        let size_bytes = req.capacity_range
            .as_ref()
            .map(|r| r.required_bytes as u64)
            .unwrap_or(0);
        let size_gb = (size_bytes + (1 << 30) - 1) / (1 << 30);
        let initiator = req.parameters.get("initiator").cloned().unwrap_or_default();

        #[derive(Serialize)]
        struct CreateReq<'a> { target_name: &'a str, size_gb: u64, initiator: &'a str }
        
        let cr = CreateReq { target_name: &req.name, size_gb, initiator: &initiator };
        let url = format!("{}/api/v1/create", self.api_url);
        let resp = self.client.post(&url)
            .bearer_auth(&self.bearer)
            .json(&cr)
            .send()
            .await
            .map_err(|e| Status::internal(format!("HTTP error: {}", e)))?;
        if !resp.status().is_success() {
            return Err(Status::internal("failed to create target"));
        }

        let portal = format!("{}:3260", self.api_url.trim_start_matches("http://").trim_start_matches("https://"));
        let mut ctx = HashMap::new();
        ctx.insert("targetPortal".into(), portal);
        ctx.insert("iqn".into(), req.name.clone());
        ctx.insert("lun".into(), "0".into());

        let vol = Volume { volume_id: req.name.clone(), capacity_bytes: size_gb << 30, volume_context: ctx, content_source: None, accessible_topology: vec![] };
        Ok(Response::new(CreateVolumeResponse { volume: Some(vol) }))
    }

    async fn delete_volume(&self, request: Request<DeleteVolumeRequest>) -> Result<Response<DeleteVolumeResponse>, Status> {
        todo!()
    }

    async fn controller_publish_volume(&self, request: Request<ControllerPublishVolumeRequest>) -> Result<Response<ControllerPublishVolumeResponse>, Status> {
        todo!()
    }

    async fn controller_unpublish_volume(&self, request: Request<ControllerUnpublishVolumeRequest>) -> Result<Response<ControllerUnpublishVolumeResponse>, Status> {
        todo!()
    }

    async fn validate_volume_capabilities(&self, request: Request<ValidateVolumeCapabilitiesRequest>) -> Result<Response<ValidateVolumeCapabilitiesResponse>, Status> {
        todo!()
    }

    async fn list_volumes(&self, request: Request<ListVolumesRequest>) -> Result<Response<ListVolumesResponse>, Status> {
        todo!()
    }

    async fn get_capacity(&self, request: Request<GetCapacityRequest>) -> Result<Response<GetCapacityResponse>, Status> {
        todo!()
    }

    async fn controller_get_capabilities(&self, request: Request<ControllerGetCapabilitiesRequest>) -> Result<Response<ControllerGetCapabilitiesResponse>, Status> {
        todo!()
    }

    async fn create_snapshot(&self, request: Request<CreateSnapshotRequest>) -> Result<Response<CreateSnapshotResponse>, Status> {
        todo!()
    }

    async fn delete_snapshot(&self, request: Request<DeleteSnapshotRequest>) -> Result<Response<DeleteSnapshotResponse>, Status> {
        todo!()
    }

    async fn list_snapshots(&self, request: Request<ListSnapshotsRequest>) -> Result<Response<ListSnapshotsResponse>, Status> {
        todo!()
    }

    async fn get_snapshot(&self, request: Request<GetSnapshotRequest>) -> Result<Response<GetSnapshotResponse>, Status> {
        todo!()
    }

    async fn controller_expand_volume(&self, request: Request<ControllerExpandVolumeRequest>) -> Result<Response<ControllerExpandVolumeResponse>, Status> {
        todo!()
    }

    async fn controller_get_volume(&self, request: Request<ControllerGetVolumeRequest>) -> Result<Response<ControllerGetVolumeResponse>, Status> {
        todo!()
    }

    async fn controller_modify_volume(&self, request: Request<ControllerModifyVolumeRequest>) -> Result<Response<ControllerModifyVolumeResponse>, Status> {
        todo!()
    }
}

#[tokio::main]
async fn main() -> Result<(), Box<dyn std::error::Error>> {
    // tracing_subscriber::fmt().init();
    // let cli = Cli::parse();
    //
    // let provisioner = ISCSIProvisioner {
    //     client: Client::new(),
    //     api_url: cli.api_url,
    //     bearer: cli.bearer_token,
    //     driver_name: "iscsi.csi.k8s.io".into(),
    //     driver_version: cli.driver_version,
    // };
    //
    // let addr = cli.endpoint.parse()?;
    // println!("CSI provisioner listening on {}", addr);
    //
    // Server::builder()
    //     .add_service(IdentityServer::new(provisioner.clone()))
    //     .add_service(ControllerServer::new(provisioner))
    //     .serve(addr)
    //     .await?;
    Ok(())
}
