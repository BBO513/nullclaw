# Testing NullClaw Zig Gateway

## Prerequisites

- Zig 0.14.1 (stable). The codebase is NOT compatible with Zig 0.16.0-dev (nightly) due to major std lib changes.
- Zig binary location on this VM: `/home/ubuntu/repos/nullclaw/zig-out/bin/nullclaw`

If Zig 0.14.1 is not installed:
```bash
cd /tmp
wget https://ziglang.org/download/0.14.1/zig-linux-x86_64-0.14.1.tar.xz
tar xf zig-linux-x86_64-0.14.1.tar.xz
export PATH="/tmp/zig-x86_64-linux-0.14.1:$PATH"
```

## Build

```bash
cd /home/ubuntu/repos/nullclaw
zig build -Doptimize=ReleaseSmall -Dtarget=x86_64-linux-musl
```

Build output: `./zig-out/bin/nullclaw`

## Configuration

Config file: `config.json` in the working directory. Schema defined in `src/config.zig`:

```json
{
    "websocket_host": "127.0.0.1",
    "websocket_port": 3000,
    "http_host": "127.0.0.1",
    "http_port": 3000,
    "secret_store_path": "/var/lib/nullclaw/secrets.enc",
    "sandbox_enabled": true,
    "max_memory_bytes": 1048576,
    "channels": [ ... ]
}
```

Fields: `websocket_host`, `websocket_port`, `http_host`, `http_port`, `secret_store_path`, `sandbox_enabled`, `max_memory_bytes`, and `channels` (array of `{ name, enabled, endpoint, auth_token_key }`).

There is no `provider`, `master_key`, or `api_key` field in the committed config.

## Running

### Doctor (diagnostics)
```bash
./zig-out/bin/nullclaw doctor
```
Runs 7 check categories (`src/doctor.zig`): Configuration (3 checks), Network Endpoints (1 port-bind check + 3 INFO lines), Communication Channels (18 channel registrations), Secret Store / ChaCha20-Poly1305 (3 checks), Sandbox / Landlock (2 checks), and Resource Limits (1 check). Total pass count depends on Landlock availability and channel health but expect 27-28 with 0 failures on a typical system.

### Gateway server
```bash
./zig-out/bin/nullclaw serve
```
Expect: `Gateway is ready. Listening...` on port 3000 (v0.1.0).

## Gateway Endpoints

The gateway (`src/gateway.zig`) routes exactly 4 paths:

### 1. `/ws` — WebSocket upgrade
Upgrades to WebSocket. Text messages are published to the internal event bus and echoed back as `{"type":"agent_response","status":"acknowledged"}`. Binary messages are published as tool calls. Pings are answered with pongs.

### 2. `POST /v1/chat/completions` — Chat completions (stub)
Accepts POST only (returns 405 for other methods). Reads the request body, publishes it to the internal event bus as an `agent_thought`, and returns a **hardcoded stub response** — it does NOT proxy to Ollama or any LLM provider.

```bash
curl -s -X POST http://127.0.0.1:3000/v1/chat/completions \
  -H "Content-Type: application/json" \
  -d '{"model":"any","messages":[{"role":"user","content":"hi"}]}'
```

Expected response:
```json
{"id":"chatcmpl-nullclaw-<timestamp>","object":"chat.completion","created":<timestamp>,"model":"nullclaw-nexus-v0.1","choices":[{"index":0,"message":{"role":"assistant","content":"NullClaw Nexus agent processing your request."},"finish_reason":"stop"}],"usage":{"prompt_tokens":0,"completion_tokens":0,"total_tokens":0}}
```

### 3. `GET /health` — Health check
```bash
curl -s http://127.0.0.1:3000/health
```

Expected response:
```json
{"status":"healthy","service":"nullclaw-nexus","version":"0.1.0"}
```

### 4. Everything else — 404
```bash
curl -s http://127.0.0.1:3000/anything-else
```

Expected response:
```json
{"error":"not_found","message":"Unknown endpoint"}
```

There is no `/status` endpoint, no `/config/provider` endpoint, no auth/X-Master-Key handling, and no SSE streaming.

## Stress Test

Fire parallel requests at the two functional endpoints to verify stability:
```bash
for i in $(seq 1 20); do curl -s http://127.0.0.1:3000/health > /dev/null 2>&1 & done
for i in $(seq 1 5); do curl -s -X POST http://127.0.0.1:3000/v1/chat/completions \
  -H "Content-Type: application/json" \
  -d '{"messages":[{"role":"user","content":"test"}]}' > /dev/null 2>&1 & done
wait
echo "All requests completed"
curl -s http://127.0.0.1:3000/health
```
Expect: All requests complete without crashes, health returns valid JSON.

## Common Issues

- **Wrong Zig version**: If build fails with unfamiliar errors, check `zig version` — must be 0.14.x, not 0.16.0-dev
- **Port in use**: If gateway fails to start, check if another instance is running on port 3000
- **Config not found**: Gateway looks for `config.json` in the current working directory

## Devin Secrets Needed

None required. The gateway has no auth and no external provider dependencies.
