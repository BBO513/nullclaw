# Testing NullClaw Zig Gateway

## Prerequisites

- Zig 0.14.1 (stable). The codebase is NOT compatible with Zig 0.16.0-dev (nightly) due to major std lib changes.
- See `.agents/skills/building-nullclaw/SKILL.md` for Zig installation instructions.

## Quick Start

```bash
cd /home/ubuntu/repos/nullclaw
zig build -Doptimize=ReleaseSmall -Dtarget=x86_64-linux-musl
./zig-out/bin/nullclaw doctor    # Verify system health (expect 27-28 passes)
./zig-out/bin/nullclaw serve     # Start gateway on port 3000
```

## Testing Endpoints

With the gateway running, open a second terminal:

### Health Check
```bash
curl -s http://127.0.0.1:3000/health
```
Expected: `{"status":"healthy","service":"nullclaw-nexus","version":"0.1.0"}`

### Chat Completions (stub)
```bash
curl -s -X POST http://127.0.0.1:3000/v1/chat/completions \
  -H "Content-Type: application/json" \
  -d '{"model":"any","messages":[{"role":"user","content":"hi"}]}'
```
Expected: OpenAI-compatible JSON with `"model":"nullclaw-nexus-v0.1"` and `"content":"NullClaw Nexus agent processing your request."`. This is a **hardcoded stub** — it does NOT call any LLM.

### Chat Completions — wrong method
```bash
curl -s http://127.0.0.1:3000/v1/chat/completions
```
Expected: `{"error":"method_not_allowed","message":"POST required"}`

### 404 for unknown paths
```bash
curl -s http://127.0.0.1:3000/anything-else
```
Expected: `{"error":"not_found","message":"Unknown endpoint"}`

### WebSocket
```bash
# If websocat is available:
echo '{"type":"ping"}' | websocat ws://127.0.0.1:3000/ws
```
Expected: `{"type":"agent_response","status":"acknowledged"}`

## Stress Test

Fire parallel requests to verify stability:
```bash
for i in $(seq 1 20); do curl -s http://127.0.0.1:3000/health > /dev/null 2>&1 & done
for i in $(seq 1 5); do curl -s -X POST http://127.0.0.1:3000/v1/chat/completions \
  -H "Content-Type: application/json" \
  -d '{"messages":[{"role":"user","content":"test"}]}' > /dev/null 2>&1 & done
wait
echo "All requests completed"
curl -s http://127.0.0.1:3000/health
```
Expect: All requests complete, health returns valid JSON, no gateway crashes.

## What Does NOT Exist on Main

Do NOT test for these — they are not implemented on the `main` branch:
- `/status` endpoint
- `/config/provider` endpoint
- `X-Master-Key` authentication
- SSE streaming responses
- Provider routing to Ollama/OpenAI/Anthropic
- `master_key` or `provider` config fields

## Common Issues

- **Wrong Zig version**: Build fails with unfamiliar errors → check `zig version`, must be 0.14.x
- **Port in use**: Gateway fails to start → check if another instance is on port 3000
- **Config not found**: Gateway looks for `config.json` in the current working directory

## Secrets Needed

None required. The gateway has no auth and no external provider dependencies.
