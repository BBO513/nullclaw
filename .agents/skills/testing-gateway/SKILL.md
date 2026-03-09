# Testing NullClaw Gateway

## Build

The gateway is written in Zig 0.14.1 (stable). The user's system may have Zig 0.16.0-dev (nightly via snap) which is incompatible.

```bash
# Ensure correct Zig version
export PATH="/tmp/zig-linux-x86_64-0.14.1:$PATH"
zig version  # Should show 0.14.1

# Build
cd /home/ubuntu/repos/nullclaw
zig build -Doptimize=ReleaseSmall -Dtarget=x86_64-linux-musl
```

If Zig 0.14.1 is not installed:
```bash
cd /tmp
wget https://ziglang.org/download/0.14.1/zig-linux-x86_64-0.14.1.tar.xz
tar xf zig-linux-x86_64-0.14.1.tar.xz
export PATH="/tmp/zig-linux-x86_64-0.14.1:$PATH"
```

## Run Gateway

```bash
./zig-out/bin/nullclaw serve
# Listens on http://127.0.0.1:3000
```

The gateway reads `config.json` in the working directory for server settings (websocket/http host and port, secret store path, sandbox config, and channel definitions). Provider configuration (model, base URL) can be updated at runtime via `POST /config/provider`.

## Diagnostics

```bash
./zig-out/bin/nullclaw doctor
# Should show 27/27 or 28/28 checks passing
```

## Testing Streaming (SSE)

Requires Ollama running locally with a model pulled.

### Install Ollama (if needed)
```bash
sudo apt-get install -y zstd  # Required for Ollama installer
curl -fsSL https://ollama.com/install.sh | sh
ollama pull smollm2:135m  # Small/fast model for testing
```

### Update config.json model
Make sure `config.json` has the correct model name matching what's pulled in Ollama (e.g. `smollm2:135m` not `llama3.1` if only smollm2 is available).

### Test streaming via curl
```bash
curl -N -X POST http://127.0.0.1:3000/v1/chat/completions \
  -H "Content-Type: application/json" \
  -d '{"model":"smollm2:135m","messages":[{"role":"user","content":"Count to 5"}],"stream":true}'
```

Expected: Multiple `data: {...}` lines arriving incrementally, ending with `data: [DONE]`.

### Test non-streaming
```bash
curl -s -X POST http://127.0.0.1:3000/v1/chat/completions \
  -H "Content-Type: application/json" \
  -d '{"model":"smollm2:135m","messages":[{"role":"user","content":"hi"}]}'
```

Expected: Single JSON response with full completion.

## Key Endpoints

- `POST /v1/chat/completions` — Chat completions (streaming if `stream:true`)
- `GET /health` — Health check
- `GET /status` — Provider status
- `POST /config/provider` — Runtime provider config update
- `OPTIONS /*` — CORS preflight

## Common Issues

- **Ollama 404**: The model name in the request must exactly match what's pulled in Ollama. Check with `ollama list`.
- **Zig build errors**: Almost always caused by using wrong Zig version. Verify with `zig version`.
- **Port conflict**: Gateway defaults to port 3000. Kill any existing process on that port first.

## Devin Secrets Needed

No secrets required for local Ollama testing. For cloud provider testing:
- `OPENAI_API_KEY` — for OpenAI provider testing
- `ANTHROPIC_API_KEY` — for Anthropic/Claude provider testing
