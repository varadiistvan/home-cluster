use axum::{
    Json, Router,
    extract::Path,
    http::StatusCode,
    routing::{get, post},
};
use chrono::Datelike;
use std::env;
use tower_http::validate_request::ValidateRequestHeaderLayer;

use crate::{get_lun_base_path, iscsi, models::Lun};
use serde::{Deserialize, Serialize};

#[derive(Deserialize, Serialize)]
struct CreateLunRequest {
    pub target_name: String,
    pub size_bytes: i64,
    pub initiator: String,
}

#[derive(Deserialize, Serialize)]
struct ResizeLunRequest {
    pub target_name: String,
    pub new_size_bytes: i64,
}

#[derive(Deserialize, Serialize)]
struct DeleteLunRequest {
    pub target_name: String,
    pub delete_store: bool,
}

async fn create_lun(
    Json(payload): Json<CreateLunRequest>,
) -> Result<Json<Lun>, (StatusCode, String)> {
    let lun_path = format!("{}/{}.img", get_lun_base_path(), payload.target_name);
    let current_date = chrono::Local::now();
    let _year = current_date.year();
    let _month = current_date.month();

    let target_name = format!("iqn.{}", &payload.target_name);
    let portal =
        iscsi::create_iscsi_portal().map_err(|e| (StatusCode::INTERNAL_SERVER_ERROR, e))?;
    match iscsi::create_and_expose_lun(
        &target_name,
        &lun_path,
        payload.size_bytes,
        &payload.initiator,
    ) {
        Ok(tid) => Ok(Json(Lun {
            id: tid,
            size_bytes: payload.size_bytes,
            initiator: payload.initiator,
            target_name,
            target_portal: portal.to_string(),
        })),
        Err(e) => Err((StatusCode::INTERNAL_SERVER_ERROR, e)),
    }
}

async fn list_luns() -> Result<Json<Vec<Lun>>, String> {
    match iscsi::list_luns() {
        Ok(luns) => Ok(Json(luns)),
        Err(e) => Err(format!("Error: {}", e)),
    }
}

async fn resize_lun(Json(payload): Json<ResizeLunRequest>) -> Json<String> {
    let lun_path = format!("{}/{}.img", get_lun_base_path(), payload.target_name);
    let target_name = format!("iqn.{}", &payload.target_name);
    match iscsi::resize_lun(&target_name, &lun_path, payload.new_size_bytes) {
        Ok(_) => Json("LUN resized successfully".to_string()),
        Err(e) => Json(format!("Error: {}", e)),
    }
}

async fn delete_lun(Json(payload): Json<DeleteLunRequest>) -> Json<String> {
    let lun_path = format!("{}/{}.img", get_lun_base_path(), payload.target_name);
    let target_name = format!("iqn.{}", &payload.target_name);
    match iscsi::delete_iscsi_lun(&target_name, &lun_path, payload.delete_store) {
        Ok(_) => Json("LUN deleted successfully".to_string()),
        Err(e) => Json(format!("Error: {}", e)),
    }
}

async fn get_lun_info(Path(target_name): Path<String>) -> Json<String> {
    let _lun_path = format!("{}/{}.img", get_lun_base_path(), target_name);
    Json(format!(
        "Info for target {} not yet implemented",
        target_name
    ))
}

pub fn get_routes() -> Router {
    Router::new()
        .route("/create", post(create_lun))
        .route("/list", get(list_luns))
        .route("/resize", post(resize_lun))
        .route("/delete", post(delete_lun))
        .route("/info/{target_name}", get(get_lun_info))
        .layer(ValidateRequestHeaderLayer::bearer(
            &env::var("ISCSI_PWD").unwrap(),
        ))
}
