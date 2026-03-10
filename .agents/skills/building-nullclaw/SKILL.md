# Building and Running NullClaw

## Zig Version

**Required: Zig 0.14.1 (stable)**. The codebase uses `std.process.argsWithAllocator` and other APIs that were removed or renamed in Zig 0.16.0-dev (nightly). Do NOT use Zig from snap (`/snap/bin/zig`) on Ubuntu — it often installs the nightly version.

Install Zig 0.14.1 manually:
```bash
cd /tmp
wget https://ziglang.org/download/0.14.1/zig-linux-x86_64-0.14.1.tar.xz
tar xf zig-linux-x86_64-0.14.1.tar.xz
export PATH="/tmp/zig-linux-x86_64-0.14.1:$PATH"
zig version  # Must show 0.14.1
```

## Build Commands

```bash
cd /home/ubuntu/repos/nullclaw

# Debug build (fast compilation)
zig build

# Release build (optimized, static musl binary)
zig build -Doptimize=ReleaseSmall -Dtarget=x86_64-linux-musl
```

Output binary: `./zig-out/bin/nullclaw`

## CLI Commands

```bash
./zig-out/bin/nullclaw serve                           # Start gateway (default: config.json in cwd)
./zig-out/bin/nullclaw serve --config /path/to/config  # Custom config path
./zig-out/bin/nullclaw doctor                          # Run 28 diagnostic checks
./zig-out/bin/nullclaw version                         # Print version
./zig-out/bin/nullclaw help                            # Show usage
```

## Project Structure

```
build.zig          # Zig build system config
build.zig.zon      # Package manifest
config.json        # Default runtime config
nullclaw.service   # systemd unit file
src/
  main.zig         # CLI entrypoint (serve, doctor, version, help)
  gateway.zig      # HTTP + WebSocket server
  config.zig       # Config struct + JSON parser
  doctor.zig       # System diagnostics (28 checks)
  event_bus.zig    # Internal pub/sub event bus
  channels.zig     # Communication channel registry (18 channels)
  secret_store.zig # ChaCha20-Poly1305 encrypted secret storage
  sandbox.zig      # Landlock LSM sandboxing
  root.zig         # Library root (unused)
```

## Configuration Schema

File: `config.json` in working directory. Parsed by `src/config.zig`.

```json
{
    "websocket_host": "127.0.0.1",
    "websocket_port": 3000,
    "http_host": "127.0.0.1",
    "http_port": 3000,
    "secret_store_path": "/var/lib/nullclaw/secrets.enc",
    "sandbox_enabled": true,
    "max_memory_bytes": 1048576,
    "channels": [
        { "name": "whatsapp", "enabled": true, "endpoint": "https://api.twilio.com/2010-04-01", "auth_token_key": "WHATSAPP_TOKEN" },
        ... (18 channels total)
    ]
}
```

Config fields: `websocket_host` (string), `websocket_port` (u16), `http_host` (string), `http_port` (u16), `secret_store_path` (string), `sandbox_enabled` (bool), `max_memory_bytes` (u64), `channels` (array of `{ name, enabled, endpoint, auth_token_key }`).

If `config.json` is not found, all fields use defaults from the struct definition in `src/config.zig`.

## Gateway Architecture

The gateway binds to a single port (default 3000) for both HTTP and WebSocket. Each incoming connection spawns a new thread (`std.Thread.spawn`).

Routes (defined in `handleRequest` in `src/gateway.zig`):

| Path | Method | Behavior |
|------|--------|----------|
| `/ws` | GET (upgrade) | WebSocket control plane — text messages echo `{"type":"agent_response","status":"acknowledged"}`, binary published as tool calls, pings answered with pongs |
| `/v1/chat/completions` | POST | Reads body, publishes to event bus as `agent_thought`, returns hardcoded stub response (does NOT proxy to any LLM) |
| `/health` | GET | Returns `{"status":"healthy","service":"nullclaw-nexus","version":"0.1.0"}` |
| `*` | any | Returns 404 `{"error":"not_found","message":"Unknown endpoint"}` |

All JSON responses include `access-control-allow-origin: *` CORS header.

## Doctor Diagnostics

`nullclaw doctor` runs 6 check categories:
1. **Configuration** (3 checks): http_port valid, websocket_port valid, memory limit sane
2. **Network Endpoints** (1 port-bind check + 3 INFO lines): tries to bind the configured port
3. **Communication Channels** (18 checks): registers all 18 default channels
4. **Secret Store** (3 checks): ChaCha20-Poly1305 encrypt/decrypt/key management
5. **Sandbox** (2 checks): Landlock LSM availability, sandbox config enabled
6. **Resource Limits** (1 check): memory envelope within bounds

Expect 27-28 passes on a typical Linux system with Landlock support (kernel 5.13+).

## systemd Deployment

```bash
sudo cp zig-out/bin/nullclaw /usr/local/bin/
sudo mkdir -p /etc/nullclaw /var/lib/nullclaw
sudo cp config.json /etc/nullclaw/
sudo useradd -r -s /usr/sbin/nologin nullclaw
sudo cp nullclaw.service /etc/systemd/system/
sudo systemctl daemon-reload
sudo systemctl enable --now nullclaw
sudo journalctl -u nullclaw -f  # View logs
```

The service file includes security hardening: NoNewPrivileges, ProtectSystem=strict, MemoryMax=1M, CPUQuota=50%.

## Common Pitfalls

- **Zig version mismatch**: `std.process.argsWithAllocator` was removed in Zig 0.15+. If you see errors about missing std functions, check `zig version`.
- **Snap Zig**: Ubuntu's snap Zig package often installs nightly (0.16.0-dev). Always install 0.14.1 manually.
- **Port 3000 in use**: Gateway fails to start if port is occupied. Kill other processes or change `http_port` in config.json.
- **Config not found**: Gateway looks for `config.json` in the current working directory, not the binary's directory.
- **Landlock warnings**: Doctor will show WARN for sandbox checks if kernel < 5.13. This is informational, not a failure.

## Secrets Needed

None. The gateway has no auth and no external provider dependencies on the main branch.
