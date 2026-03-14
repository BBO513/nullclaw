/**
 * Tauri Integration Layer
 * 
 * Provides gateway auto-discovery and sidecar management when running
 * inside a Tauri desktop wrapper. Falls back gracefully when running
 * as a regular web app in the browser.
 */

/** Check if we're running inside a Tauri webview */
export function isTauri(): boolean {
  return typeof window !== 'undefined' && '__TAURI_INTERNALS__' in window;
}

/**
 * Auto-discover the gateway URL by trying multiple ports.
 * When running in Tauri, uses the Rust backend command.
 * When running in browser, probes ports via fetch.
 */
export async function discoverGateway(): Promise<string | null> {
  if (isTauri()) {
    try {
      const { invoke } = await import('@tauri-apps/api/core');
      const url = await invoke<string>('discover_gateway');
      return url;
    } catch {
      // Sidecar not found or not started, fall through to browser discovery
    }
  }

  // Browser-based discovery: try common ports
  const ports = [3000, 3001, 3333, 8080];
  for (const port of ports) {
    try {
      const response = await fetch(`http://127.0.0.1:${port}/health`, {
        signal: AbortSignal.timeout(2000)
      });
      if (response.ok) {
        return `http://127.0.0.1:${port}`;
      }
    } catch {
      // Port not responding, try next
    }
  }

  // Also try localhost (in case of different DNS resolution)
  for (const port of ports) {
    try {
      const response = await fetch(`http://localhost:${port}/health`, {
        signal: AbortSignal.timeout(2000)
      });
      if (response.ok) {
        return `http://localhost:${port}`;
      }
    } catch {
      // Port not responding, try next
    }
  }

  return null;
}

/**
 * Start the gateway sidecar (Tauri only).
 * Returns the gateway URL or null if not in Tauri.
 */
export async function startGateway(port: number = 3000): Promise<string | null> {
  if (!isTauri()) return null;

  try {
    const { invoke } = await import('@tauri-apps/api/core');
    return await invoke<string>('start_gateway', { port });
  } catch (e) {
    console.error('[Tauri] Failed to start gateway:', e);
    return null;
  }
}

/**
 * Stop the gateway sidecar (Tauri only).
 */
export async function stopGateway(): Promise<void> {
  if (!isTauri()) return;

  try {
    const { invoke } = await import('@tauri-apps/api/core');
    await invoke('stop_gateway');
  } catch (e) {
    console.error('[Tauri] Failed to stop gateway:', e);
  }
}

/**
 * Check if the gateway sidecar is running (Tauri only).
 */
export async function isGatewayRunning(): Promise<boolean> {
  if (!isTauri()) return false;

  try {
    const { invoke } = await import('@tauri-apps/api/core');
    return await invoke<boolean>('gateway_status');
  } catch {
    return false;
  }
}

/**
 * Listen for gateway events from Tauri backend.
 */
export async function onGatewayStarted(callback: (url: string) => void): Promise<(() => void) | null> {
  if (!isTauri()) return null;

  try {
    const { listen } = await import('@tauri-apps/api/event');
    const unlisten = await listen<string>('gateway-started', (event) => {
      callback(event.payload);
    });
    return unlisten;
  } catch {
    return null;
  }
}

/**
 * Listen for gateway error events from Tauri backend.
 */
export async function onGatewayError(callback: (error: string) => void): Promise<(() => void) | null> {
  if (!isTauri()) return null;

  try {
    const { listen } = await import('@tauri-apps/api/event');
    const unlisten = await listen<string>('gateway-error', (event) => {
      callback(event.payload);
    });
    return unlisten;
  } catch {
    return null;
  }
}
