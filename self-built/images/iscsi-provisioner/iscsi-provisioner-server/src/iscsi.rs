use crate::models::Lun;
use std::path::Path;
use std::process::{Command, Output};
use std::{env, fs};
use xattr::{get, set};

// Utility to run a command and get its output with error handling
fn run_command(command: &str, args: &[&str]) -> Result<Output, String> {
    let output = Command::new(command)
        .args(args)
        .output()
        .map_err(|e| format!("Failed to execute command '{}': {}", command, e))?;

    if !output.status.success() {
        let stderr = String::from_utf8_lossy(&output.stderr);
        return Err(format!("Command '{}' failed: {}", command, stderr.trim()));
    }

    Ok(output)
}

pub fn create_and_expose_lun(
    target_name: &str,
    lun_path: &str,
    size_gb: u64,
    initiator_cidr: &str,
) -> Result<usize, String> {
    // Create the LUN image file using existing function
    create_lun_image(lun_path, size_gb).map_err(|e| format!("Error creating LUN image: {}", e))?;

    // Mark the LUN as managed by this service using xattr
    set_api_managed_xattr(lun_path).map_err(|e| format!("Error setting xattr: {}", e))?;

    // Create and expose the LUN via iSCSI using existing function
    create_iscsi_lun(target_name, lun_path, initiator_cidr)
        .map_err(|e| format!("Failed to create and expose LUN: {}", e))
}

// Utility: Create a LUN image file
fn create_lun_image(path: &str, size_gb: u64) -> Result<Output, String> {
    let exists = Path::new(path).try_exists();

    if exists.is_err() || exists.is_ok_and(|e| e) {
        return Err("Image file already exists".into());
    }

    run_command(
        "qemu-img",
        &["create", "-f", "raw", path, &format!("{}G", size_gb)],
    )
    .map_err(|e| format!("Error creating LUN image: {}", e))
}

// Utility: Set xattr to mark a LUN as API-managed
fn set_api_managed_xattr(path: &str) -> Result<(), String> {
    set(path, "user.iscsi-api", b"managed").map_err(|e| format!("Error setting xattr: {}", e))
}

// Utility: Get LUN image size using qemu-img info
fn get_lun_size(path: &str) -> Result<u64, String> {
    let output = run_command("qemu-img", &["info", "--output", "json", path])?;
    let info: serde_json::Value = serde_json::from_slice(&output.stdout)
        .map_err(|e| format!("Failed to parse qemu-img info JSON: {}", e))?;

    if let Some(virtual_size) = info["virtual-size"].as_u64() {
        Ok(virtual_size / (1024 * 1024 * 1024)) // Convert bytes to GB
    } else {
        Err("Failed to retrieve LUN size from qemu-img info".to_string())
    }
}

// Utility: Check if a LUN is API-managed using xattr
fn is_api_managed(path: &str) -> Result<bool, String> {
    match get(path, "user.iscsi-api") {
        Ok(Some(value)) => Ok(value == b"managed"),
        Ok(None) => Ok(false),
        Err(e) => Err(format!("Error getting xattr: {}", e)),
    }
}
// List all API-managed LUNs with detailed metadata
pub fn list_luns() -> Result<Vec<Lun>, String> {
    let output = run_command(
        "tgtadm",
        &["--lld", "iscsi", "--mode", "target", "--op", "show"],
    )?;
    let stdout = String::from_utf8_lossy(&output.stdout);

    let mut luns = Vec::new();
    let mut current_target = String::new();
    let mut target_portal = String::new();

    for line in stdout.lines() {
        if line.contains("Target ") {
            let parts: Vec<&str> = line.split_whitespace().collect();
            if parts.len() > 2 {
                current_target = parts[2].to_string();
            }
        }

        if line.contains("Portal: ") {
            let parts: Vec<&str> = line.split_whitespace().collect();
            if parts.len() > 1 {
                target_portal = parts[1].to_string();
            }
        }

        if line.contains("LUN:") {
            let parts: Vec<&str> = line.split_whitespace().collect();
            if parts.len() >= 4 {
                let lun_path = parts[3];
                if let Ok(size_gb) = get_lun_size(lun_path) {
                    luns.push(Lun {
                        id: 1,
                        size_gb,
                        initiator: "".to_string(),
                        target_name: current_target.clone(),
                        target_portal: target_portal.clone(),
                    });
                }
            }
        }
    }

    Ok(luns)
}

// Resize a LUN and dynamically update the iSCSI target
pub fn resize_lun(target_name: &str, path: &str, new_size_gb: u64) -> Result<(), String> {
    if !is_api_managed(path)? {
        return Err("LUN is not managed by API".to_string());
    }

    let current_size_gb = get_lun_size(path)?;

    if new_size_gb == current_size_gb {
        return Ok(()); // No action needed if the size is unchanged
    }

    if new_size_gb < current_size_gb {
        return Err("Cannot resize to a smaller size".to_string());
    }

    // Resize the LUN image
    run_command("qemu-img", &["resize", path, &format!("{}G", new_size_gb)])?;

    // Directly update the LUN in the iSCSI target without deleting
    run_command(
        "tgtadm",
        &[
            "--lld",
            "iscsi",
            "--mode",
            "logicalunit",
            "--op",
            "update",
            "--targetname",
            target_name,
            "--lun",
            "0",
            "--backing-store",
            path,
        ],
    )
    .map_err(|e| format!("Failed to update LUN in target '{}': {}", target_name, e))?;

    Ok(())
}

// Utility: Get the next available TID for a new target
fn get_next_available_tid() -> Result<usize, String> {
    let output = run_command(
        "tgtadm",
        &["--lld", "iscsi", "--mode", "target", "--op", "show"],
    )?;
    let stdout = String::from_utf8_lossy(&output.stdout);

    let mut max_tid = 0;
    for line in stdout.lines() {
        if line.trim().starts_with("Target") {
            if let Some(tid) = line.split_whitespace().nth(1).and_then(|s| {
                let s: String = s.chars().filter(|c| c.is_ascii_digit()).collect();
                s.parse().ok()
            }) {
                if tid > max_tid {
                    max_tid = tid;
                }
            }
        }
    }

    Ok(max_tid + 1) // Next available TID
}

pub fn create_iscsi_portal() -> Result<u16, String> {
    // 1) Determine desired portal address
    let portal_port: u16 = env::var("ISCSI_PORTAL")
        .map(|p| p.parse().expect("Invalid portal address"))
        .unwrap_or(3260);
    let portal = format!("0.0.0.0:{portal_port}");

    // 2) List existing portals
    let output = run_command(
        "tgtadm",
        &["--lld", "iscsi", "--mode", "portal", "--op", "show"],
    )
    .map_err(|e| format!("Failed to list portals: {}", e))?;

    let stdout = String::from_utf8_lossy(&output.stdout);
    dbg!(&stdout);
    // If it's already present, just return it
    if stdout.lines().any(|line| line.contains(&portal)) {
        return Ok(portal_port);
    }

    // 3) Otherwise, create it
    run_command(
        "tgtadm",
        &[
            "--lld",
            "iscsi",
            "--mode",
            "portal",
            "--op",
            "new",
            "--param",
            &format!("portal={}", &portal),
        ],
    )
    .map_err(|e| format!("Failed to create portal {}: {}", portal, e))?;

    Ok(portal_port)
}

// Utility: Create and expose an iSCSI LUN with dynamic target
fn create_iscsi_lun(
    target_name: &str,
    lun_path: &str,
    initiator_cidr: &str,
) -> Result<usize, String> {
    // Determine the next available TID
    let next_tid = get_next_available_tid()?;

    // Create iSCSI target with the specified name using dynamic TID
    run_command(
        "tgtadm",
        &[
            "--lld",
            "iscsi",
            "--mode",
            "target",
            "--op",
            "new",
            "--tid",
            &next_tid.to_string(),
            "--targetname",
            target_name,
        ],
    )
    .map_err(|e| format!("Failed to create iSCSI target '{}': {}", target_name, e))?;

    run_command(
        "tgtadm",
        &[
            "--lld",
            "iscsi",
            "--mode",
            "target",
            "--op",
            "bind",
            "--tid",
            &next_tid.to_string(),
            "--initiator-address",
            initiator_cidr,
        ],
    )
    .map_err(|e| format!("Failed to bind portal to target '{}': {}", target_name, e))?;

    dbg!(lun_path);
    dbg!(next_tid);

    // Attach the LUN to the target with LUN ID 1
    run_command(
        "tgtadm",
        &[
            "--lld",
            "iscsi",
            "--mode",
            "logicalunit",
            "--op",
            "new",
            "--tid",
            &next_tid.to_string(),
            "--lun",
            "1",
            "--backing-store",
            lun_path,
        ],
    )
    .map_err(|e| format!("Failed to attach LUN to target '{}': {}", target_name, e))?;

    Ok(next_tid)
}

fn list_active_connections(target_name: &str) -> Result<bool, String> {
    let tid = get_tid_for_target(target_name)?;
    let output = run_command(
        "tgtadm",
        &[
            "--lld",
            "iscsi",
            "--mode",
            "conn",
            "--op",
            "show",
            "--tid",
            &tid.to_string(),
        ],
    )?;
    Ok(String::from_utf8_lossy(&output.stdout).contains(target_name))
}

fn get_initiator_cidr(target_name: &str) -> Result<String, String> {
    let output = run_command(
        "tgtadm",
        &[
            "--lld",
            "iscsi",
            "--mode",
            "target",
            "--op",
            "show",
            "--targetname",
            target_name,
        ],
    )?;

    let stdout = String::from_utf8_lossy(&output.stdout);
    for line in stdout.lines() {
        // assume the line looks like: "    Initiator CIDR: 192.168.1.0/24"
        if let Some(rest) = line.trim().strip_prefix("Initiator CIDR:") {
            return Ok(rest.trim().to_string());
        }
    }

    Err("Failed to parse Initiator CIDR from existing target".to_string())
}

// Function: ACID Rename an iSCSI LUN target, handling active connections
pub fn rename_iscsi_target(
    old_target_name: &str,
    new_target_name: &str,
    lun_path: &str,
) -> Result<(), String> {
    if list_active_connections(old_target_name)? {
        return Err("Cannot rename: Active connections detected".to_string());
    }

    let output = run_command(
        "tgtadm",
        &["--lld", "iscsi", "--mode", "target", "--op", "show"],
    )?;
    if String::from_utf8_lossy(&output.stdout).contains(new_target_name) {
        return Err("New target name already exists".to_string());
    }

    let initiator_cidr = get_initiator_cidr(old_target_name)?;

    create_iscsi_lun(new_target_name, lun_path, &initiator_cidr)?;

    if let Err(e) = run_command(
        "tgtadm",
        &[
            "--lld",
            "iscsi",
            "--mode",
            "target",
            "--op",
            "delete",
            "--targetname",
            old_target_name,
        ],
    ) {
        run_command(
            "tgtadm",
            &[
                "--lld",
                "iscsi",
                "--mode",
                "target",
                "--op",
                "delete",
                "--targetname",
                new_target_name,
            ],
        )?;
        return Err(format!("Failed to delete old target: {}. Rolled back.", e));
    }

    Ok(())
}

// Function: Delete an iSCSI LUN with optional store deletion, handling active connections
pub fn delete_iscsi_lun(
    target_name: &str,
    lun_path: &str,
    delete_store: bool,
) -> Result<(), String> {
    let active_connections = list_active_connections(target_name);

    if active_connections.is_err() || !active_connections.unwrap() {
        println!("No active connections found for target: {}", target_name);
    } else {
        return Err(format!(
            "Cannot delete target '{}': Active connections detected",
            target_name
        ));
    }

    let tid = get_tid_for_target(target_name)
        .map_err(|e| format!("Failed to get TID for target '{}': {}", target_name, e));

    if tid.is_ok() {
        if let Err(e) = run_command(
            "tgtadm",
            &[
                "--lld",
                "iscsi",
                "--mode",
                "target",
                "--op",
                "delete",
                "--tid",
                &tid.unwrap().to_string(),
            ],
        ) {
            eprintln!("{e}");
        };
    }

    if delete_store {
        fs::remove_file(lun_path)
            .map_err(|e| format!("Failed to delete LUN image '{}': {}", lun_path, e))?;
    }

    Ok(())
}

fn get_tid_for_target(target_name: &str) -> Result<usize, String> {
    // 1) List all targets
    let output = run_command(
        "tgtadm",
        &["--lld", "iscsi", "--mode", "target", "--op", "show"],
    )
    .map_err(|e| format!("Failed to list iSCSI targets: {}", e))?;

    // 2) Parse stdout line by line
    let stdout = String::from_utf8_lossy(&output.stdout);
    for line in stdout.lines() {
        let line = line.trim();
        // Look for lines like: "Target 3: iqn.2025-06.com.example:target1"
        if let Some(rest) = line.strip_prefix("Target ") {
            if let Some((tid_str, name)) = rest.split_once(':') {
                let name = name.trim();
                if name == target_name {
                    let tid = tid_str
                        .trim()
                        .parse::<usize>()
                        .map_err(|e| format!("Failed to parse TID '{}': {}", tid_str, e))?;
                    return Ok(tid);
                }
            }
        }
    }

    Err(format!("TID for target '{}' not found", target_name))
}
