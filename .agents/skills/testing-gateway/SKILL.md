# Testing NullClaw Zig Gateway

## Prerequisites

- Zig 0.14.1 (stable). The codebase is NOT compatible with Zig 0.16.0-dev (nightly) due to major std lib changes.
- Zig binary location on this VM: `/home/ubuntu/repos/nullclaw/zig-out/bin/nullclaw`
- If Zig is not installed, download from: `https://ziglang.org/download/0.14.1/zig-linux-x86_64-0.14.1.tar.xz`

## Build

```bash
cd /home/ubuntu/repos/nullclaw
zig build -Doptimize=ReleaseSmall -Dtarget=x86_64-linux-musl
```

Build output: `./zig-out/bin/nullclaw`

## Configuration

- Config file: `config.json` in the working directory
- Key fields for testing:
  - `master_key`: Set to a test value (e.g. `"test-secret-123"`) for auth testing
  - `provider.type`: `"ollama"` for local testing
  - `provider.base_url`: `"http://localhost:11434"` for Ollama
  - `provider.model`: Any model name (e.g. `"smollm2:135m"`)

## Running

### Doctor (diagnostics)
```bash
./zig-out/bin/nullclaw doctor
```
Expect: 27+ checks passed with 0 failures.

### Gateway server
```bash
./zig-out/bin/nullclaw serve
```
Expect: "Gateway ready. Listening..." on port 3000.

## Test Endpoints

### GET /status (returns provider info + uptime)
```bash
curl -s http://127.0.0.1:3000/status | python3 -m json.tool
```

### GET /config/provider (returns current provider config)
```bash
curl -s http://127.0.0.1:3000/config/provider | python3 -m json.tool
```

### POST /v1/chat/completions (forwards to LLM provider)
```bash
curl -s -X POST http://127.0.0.1:3000/v1/chat/completions \
  -H "Content-Type: application/json" \
  -d '{"model":"smollm2:135m","messages":[{"role":"user","content":"say hi"}]}'
```
Note: Requires Ollama (or configured provider) running. If provider is down, expect a connection error JSON — NOT a crash.

### POST /config/provider (auth-protected provider update)

Without key (expect 401):
```bash
curl -s -X POST http://127.0.0.1:3000/config/provider \
  -H "Content-Type: application/json" -d '{"model":"test"}'
```

With wrong key (expect 403):
```bash
curl -s -X POST http://127.0.0.1:3000/config/provider \
  -H "Content-Type: application/json" -H "X-Master-Key: wrong" -d '{"model":"test"}'
```

With correct key (expect 200):
```bash
curl -s -X POST http://127.0.0.1:3000/config/provider \
  -H "Content-Type: application/json" -H "X-Master-Key: test-secret-123" \
  -d '{"model":"new-model"}'
```

### GET /health
```bash
curl -s http://127.0.0.1:3000/health | python3 -m json.tool
```

## Concurrent Stress Test

To verify thread safety of the deep-copy mutex pattern:
```bash
for i in $(seq 1 20); do curl -s http://127.0.0.1:3000/status > /dev/null 2>&1 & done
for i in $(seq 1 5); do curl -s -X POST http://127.0.0.1:3000/config/provider \
  -H "Content-Type: application/json" -H "X-Master-Key: test-secret-123" \
  -d "{\"model\":\"stress-$i\"}" > /dev/null 2>&1 & done
wait
curl -s http://127.0.0.1:3000/status | python3 -m json.tool
```
Expect: All requests complete, no crashes, final status shows last update.

## SSE Streaming Test

```bash
curl -N -X POST http://127.0.0.1:3000/v1/chat/completions \
  -H "Content-Type: application/json" \
  -d '{"model":"smollm2:135m","messages":[{"role":"user","content":"hi"}],"stream":true}'
```
Expect: `data: {...}` lines arriving incrementally, ending with `data: [DONE]`.

## Common Issues

- **Wrong Zig version**: If build fails with unfamiliar errors, check `zig version` — must be 0.14.x, not 0.16.0-dev
- **Port in use**: If gateway fails to start, check if another instance is running on port 3000
- **Ollama not running**: Chat completions will return connection error JSON, but gateway should NOT crash
- **Config not found**: Gateway looks for `config.json` in the current working directory

## Devin Secrets Needed

None required for local testing. The `master_key` is set in `config.json` for auth testing.
