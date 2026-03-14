use crate::GatewayState;
use tauri_plugin_shell::ShellExt;
use std::net::TcpStream;
use std::time::Duration;

/// Ports to try when discovering a running gateway
const DISCOVERY_PORTS: &[u16] = &[3000, 3001, 3333, 8080];

/// Start the NullClaw gateway as a sidecar process
pub async fn start_gateway_sidecar(
    app: &tauri::AppHandle,
    state: &tauri::State<'_, GatewayState>,
    port: u16,
) -> Result<String, String> {
    // Check if already running
    {
        let child = state.child.lock().map_err(|e| e.to_string())?;
        if child.is_some() {
            return Ok(format!("http://127.0.0.1:{}", port));
        }
    }

    // Try to spawn the sidecar binary
    let sidecar_command = app
        .shell()
        .sidecar("nullclaw")
        .map_err(|e| format!("Failed to create sidecar command: {}", e))?
        .args(["serve", "--bind", &format!("127.0.0.1:{}", port)]);

    let (mut rx, child) = sidecar_command
        .spawn()
        .map_err(|e| format!("Failed to spawn gateway: {}", e))?;

    // Store the child process
    {
        let mut child_lock = state.child.lock().map_err(|e| e.to_string())?;
        *child_lock = Some(child);
    }

    // Monitor sidecar output in background
    tauri::async_runtime::spawn(async move {
        while let Some(event) = rx.recv().await {
            match event {
                tauri_plugin_shell::process::CommandEvent::Stdout(line) => {
                    println!("[Gateway] {}", String::from_utf8_lossy(&line));
                }
                tauri_plugin_shell::process::CommandEvent::Stderr(line) => {
                    eprintln!("[Gateway] {}", String::from_utf8_lossy(&line));
                }
                tauri_plugin_shell::process::CommandEvent::Terminated(status) => {
                    println!("[Gateway] Process terminated with status: {:?}", status);
                    break;
                }
                _ => {}
            }
        }
    });

    // Wait briefly for gateway to start, then verify it's listening
    tokio::time::sleep(Duration::from_millis(1000)).await;

    let url = format!("http://127.0.0.1:{}", port);
    if check_port_open(port) {
        Ok(url)
    } else {
        // Give it more time
        tokio::time::sleep(Duration::from_millis(2000)).await;
        if check_port_open(port) {
            Ok(url)
        } else {
            Ok(format!("{} (starting...)", url))
        }
    }
}

/// Stop the gateway sidecar process
pub fn stop_gateway_sidecar(
    state: &tauri::State<'_, GatewayState>,
) -> Result<(), String> {
    let mut child = state.child.lock().map_err(|e| e.to_string())?;
    if let Some(child_process) = child.take() {
        child_process.kill().map_err(|e| format!("Failed to kill gateway: {}", e))?;
        println!("[NullClaw] Gateway stopped");
    }
    Ok(())
}

/// Discover a running gateway by probing multiple ports
pub async fn discover_gateway() -> Result<String, String> {
    for port in DISCOVERY_PORTS {
        if check_port_open(*port) {
            return Ok(format!("http://127.0.0.1:{}", port));
        }
    }
    Err("No gateway found on any known port".to_string())
}

/// Check if a port is open (gateway is listening)
fn check_port_open(port: u16) -> bool {
    TcpStream::connect_timeout(
        &format!("127.0.0.1:{}", port).parse().unwrap(),
        Duration::from_secs(2),
    )
    .is_ok()
}
