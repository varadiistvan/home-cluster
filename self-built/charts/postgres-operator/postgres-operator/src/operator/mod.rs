use base64::prelude::*;
use k8s_openapi::api::core::v1::Secret;
use kube::Api;

mod db;
mod db_stream;
mod secret_stream;
mod user;
mod user_stream;

pub use db::*;
pub use db_stream::*;
pub use secret_stream::*;
pub use user::*;
pub use user_stream::*;

pub async fn get_string_value_from_secret(
    key: &str,
    secret_api: &Api<Secret>,
    secret_name: &str,
) -> Result<String, String> {
    let secret = secret_api.get(secret_name).await;

    if secret.is_err() {
        return Err(format!("Could not get secret: {}, {secret:?}", secret_name));
    }

    let secret_data = secret.unwrap().data;

    if secret_data.is_none() {
        return Err(format!("Secret {secret_name} has no data"));
    }

    let secret_data = secret_data.unwrap();

    let value = secret_data.get(key);

    if value.is_none() {
        return Err(format!("Secret {secret_name} has no key {key}"));
    }

    let value = value.unwrap();

    // if let Ok(decoded) = BASE64_STANDARD.decode(&value.0) {
    if let Ok(string_value) = String::from_utf8(value.0.clone()) {
        return Ok(string_value);
    } else {
        // return Err(format!("Couldn't convert decoded base64 to string {decoded:?}, from secret {secret_name} key {key}"));
        return Err(format!(
            "Couldn't build string from {0:?}, from secret {secret_name} key {key}",
            value.0
        ));
    }
    // } else {
    //     return Err(format!(
    //         "Couldn't decode base64 {value:?}, from secret {secret_name} key {key}"
    //     ));
    // }
}
