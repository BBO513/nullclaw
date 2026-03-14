use tauri::Manager;
use tauri::Emitter;
use std::sync::Mutex;

mod gateway;

/// Shared state for tracking the gateway sidecar process
pub struct GatewayState {
    pub child: Mutex<Option<tauri_plugin_shell::process::CommandChild>>,
}

#[tauri::command]
async fn start_gateway(
    app: tauri::AppHandle,
    state: tauri::State<'_, GatewayState>,
    port: Option<u16>,
) -> Result<String, String> {
    gateway::start_gateway_sidecar(&app, &state, port.unwrap_or(3000)).await
}

#[tauri::command]
async fn stop_gateway(
    state: tauri::State<'_, GatewayState>,
) -> Result<(), String> {
    gateway::stop_gateway_sidecar(&state)
}

#[tauri::command]
async fn discover_gateway() -> Result<String, String> {
    gateway::discover_gateway().await
}

#[tauri::command]
async fn gateway_status(
    state: tauri::State<'_, GatewayState>,
) -> Result<bool, String> {
    let child = state.child.lock().map_err(|e| e.to_string())?;
    Ok(child.is_some())
}

#[cfg_attr(mobile, tauri::mobile_entry_point)]
pub fn run() {
    tauri::Builder::default()
        .plugin(tauri_plugin_shell::init())
        .plugin(tauri_plugin_process::init())
        .manage(GatewayState {
            child: Mutex::new(None),
        })
        .invoke_handler(tauri::generate_handler![
            start_gateway,
            stop_gateway,
            discover_gateway,
            gateway_status,
        ])
        .setup(|app| {
            // Auto-start gateway on app launch
            let app_handle = app.handle().clone();
            tauri::async_runtime::spawn(async move {
                // Small delay to let the window render first
                tokio::time::sleep(std::time::Duration::from_millis(500)).await;

                let state: tauri::State<'_, GatewayState> = app_handle.state();
                match gateway::start_gateway_sidecar(&app_handle, &state, 3000).await {
                    Ok(url) => {
                        println!("[NullClaw] Gateway auto-started at {}", url);
                        // Emit event to frontend
                        let _ = app_handle.emit("gateway-started", url);
                    }
                    Err(e) => {
                        eprintln!("[NullClaw] Failed to auto-start gateway: {}", e);
                        let _ = app_handle.emit("gateway-error", e);
                    }
                }
            });

            Ok(())
        })
        .on_window_event(|window, event| {
            // Stop gateway when app closes
            if let tauri::WindowEvent::Destroyed = event {
                let state: tauri::State<'_, GatewayState> = window.app_handle().state();
                let _ = gateway::stop_gateway_sidecar(&state);
            }
        })
        .run(tauri::generate_context!())
        .expect("error while running NullClaw Nexus");
}
