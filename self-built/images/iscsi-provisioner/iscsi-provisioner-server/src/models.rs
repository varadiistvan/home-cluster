use serde::{Deserialize, Serialize};

// Struct for a LUN (Logical Unit Number)
#[derive(Debug, Serialize, Deserialize, Clone)]
pub struct Lun {
    pub id: usize,
    pub size_bytes: i64,
    pub initiator: String,
    pub target_name: String,
    pub target_portal: String,
}
