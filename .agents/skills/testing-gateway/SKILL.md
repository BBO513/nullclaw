# Testing NullClaw Zig Gateway

## Prerequisites

- Zig 0.14.1 (stable). The codebase is NOT compatible with Zig 0.16.0-dev (nightly) due to major std lib changes.
- Zig binary location on this VM: `/home/ubuntu/repos/nullclaw/zig-out/bin/nullclaw`

If Zig 0.14.1 is not installed:
```bash
cd /tmp
wget https://ziglang.org/download/0.14.1/zig-linux-x86_64-0.14.1.tar.xz
tar xf zig-linux-x86_64-0.14.1.tar.xz
export PATH="/tmp/zig-linux-x86_64-0.14.1:$PATH"
```

## Build

```bash
cd /home/ubuntu/repos/nullclaw
zig build -Doptimize=ReleaseSafe -Dtarget=x86_64-linux-musl
```

Build output: `./zig-out/bin/nullclaw`

## Configuration

Config file: `config.json` in the working directory. Schema defined in `src/config.zig`.

Key fields for testing:
- `master_key`: Set in config.json or via `NULLCLAW_MASTER_KEY` env var for auth testing
- `provider.type`: `"ollama"` for local testing
- `provider.base_url`: `"http://localhost:11434"` for Ollama
- `provider.model`: Any model name (e.g. `"llama3.1"`)

If no `master_key` is configured (config + env), all endpoints are unprotected (dev mode).

## Running

### Doctor (diagnostics)
```bash
./zig-out/bin/nullclaw doctor
```
Expect: 27-28 checks passed with 0 failures.

### Gateway server
```bash
./zig-out/bin/nullclaw serve
```
Expect: "Gateway ready. Listening..." on port 3000 (v0.2.0).

### Gateway server with auth enabled
```bash
NULLCLAW_MASTER_KEY=test-secret-123 ./zig-out/bin/nullclaw serve
```

## Gateway Endpoints

The gateway (`src/gateway.zig`) routes these paths:

### 1. `GET /health` — Health check (NO auth required)
```bash
curl -s http://127.0.0.1:3000/health
```
Expected: `{"status":"healthy","service":"nullclaw-nexus","version":"0.2.0"}`

### 2. `GET /status` — Provider status (auth required)
```bash
curl -s -H "Authorization: Bearer test-secret-123" http://127.0.0.1:3000/status
```
Expected: JSON with `status`, `version`, `uptime_seconds`, `provider` object.

### 3. `/config/provider` — Provider config GET/POST (auth required)
```bash
# GET current config
curl -s -H "Authorization: Bearer test-secret-123" http://127.0.0.1:3000/config/provider

# POST update config
curl -s -X POST -H "Authorization: Bearer test-secret-123" -H "Content-Type: application/json" \
  -d '{"model":"new-model"}' http://127.0.0.1:3000/config/provider
```

### 4. `POST /v1/chat/completions` — Chat completions (auth required)
```bash
curl -s -X POST -H "Authorization: Bearer test-secret-123" -H "Content-Type: application/json" \
  -d '{"model":"llama3.1","messages":[{"role":"user","content":"hi"}]}' \
  http://127.0.0.1:3000/v1/chat/completions
```
Note: Requires Ollama (or configured provider) running. If provider is down, expect a connection error JSON, NOT a crash.

### 5. `/ws` — WebSocket (auth required)
WebSocket upgrade endpoint. Requires auth when master key is configured.

### 6. Everything else — 404
```bash
curl -s http://127.0.0.1:3000/anything-else
```
Expected: `{"error":"not_found","message":"Unknown endpoint"}`

## Testing Auth (Bug 5)

Start the gateway with `NULLCLAW_MASTER_KEY=test-secret-123` env var.

| Test | Command | Expected |
|------|---------|----------|
| Health (no auth) | `curl -s http://127.0.0.1:3000/health` | 200 OK |
| Protected without auth | `curl -s http://127.0.0.1:3000/status` | 401 Unauthorized |
| Protected with wrong token | `curl -s -H "Authorization: Bearer wrong" http://127.0.0.1:3000/status` | 403 Forbidden |
| Protected with correct Bearer | `curl -s -H "Authorization: Bearer test-secret-123" http://127.0.0.1:3000/status` | 200 OK |
| X-Master-Key backward compat | `curl -s -H "X-Master-Key: test-secret-123" http://127.0.0.1:3000/status` | 200 OK |
| POST without auth | `curl -s -X POST http://127.0.0.1:3000/config/provider -d '{}'` | 401 |
| POST with auth | `curl -s -X POST -H "Authorization: Bearer test-secret-123" -H "Content-Type: application/json" -d '{"model":"test"}' http://127.0.0.1:3000/config/provider` | 200 |

**Known edge case (minor):** If a client sends both `Authorization: Basic xyz` (non-Bearer) AND `X-Master-Key: valid-key`, the `X-Master-Key` may not be reached because the loop breaks on the Authorization header. This only affects clients sending both headers simultaneously, which is unusual.

## Testing Thread Safety (Bug 6 + TOCTOU)

Run concurrent readers and writers against the gateway for 30+ seconds:

**Terminal A (reader — 300 requests):**
```bash
for i in $(seq 1 300); do
  curl -s -H "Authorization: Bearer test-secret-123" http://127.0.0.1:3000/status > /dev/null 2>&1
  sleep 0.1
done
echo "READER DONE"
```

**Terminal B (writer — 150 requests):**
```bash
for i in $(seq 1 150); do
  curl -s -X POST -H "Authorization: Bearer test-secret-123" -H "Content-Type: application/json" \
    -d "{\"model\":\"stress-$i\"}" http://127.0.0.1:3000/config/provider > /dev/null 2>&1
  sleep 0.2
done
echo "WRITER DONE"
```

Expect: Both loops complete with exit code 0, no gateway crashes or errors.

After stress test, verify:
```bash
curl -s http://127.0.0.1:3000/health  # Should return healthy
curl -s -H "Authorization: Bearer test-secret-123" http://127.0.0.1:3000/status  # Should show last stress model
```

## Common Issues

- **Wrong Zig version**: Build fails with unfamiliar errors. Check `zig version` — must be 0.14.x, not 0.16.0-dev
- **Port in use**: Gateway fails to start. Kill any existing process on port 3000
- **Config not found**: Gateway looks for `config.json` in the current working directory
- **Auth issues in dev mode**: If no master_key is set, all endpoints are open (no auth check). Set `NULLCLAW_MASTER_KEY` env var for testing auth.
- **Feature branches not on main**: PRs may merge into intermediate branches (not main directly). Check PR target branch. Use `git fetch origin && git checkout origin/<branch>` to test.

## Devin Secrets Needed

No secrets required for local testing. For cloud provider testing:
- `OPENAI_API_KEY` — for OpenAI provider testing
- `ANTHROPIC_API_KEY` — for Anthropic/Claude provider testing
