# 🚀 NullClaw Nexus - Startup Options

## Quick Reference

| File | What It Does |
|------|--------------|
| `start.bat` | UI only (no backend) |
| `start-with-gateway.bat` | UI + NullClaw Gateway |
| `start-with-ollama.bat` | UI + NullClaw Gateway + Ollama |

## Option 1: UI Only (Default)

**File:** `start.bat`

**What it starts:**
- ✅ NullClaw Nexus Web UI

**What you can do:**
- Browse the interface
- Explore all pages
- Upload memory files
- Configure settings

**What won't work:**
- ❌ Actual AI chat (needs gateway)
- ❌ Agent responses

**When to use:**
- Just want to see the UI
- Developing frontend features
- Don't have NullClaw binary yet

**How to start:**
```cmd
Double-click: start.bat
```

---

## Option 2: UI + Gateway

**File:** `start-with-gateway.bat`

**What it starts:**
- ✅ NullClaw Gateway (backend)
- ✅ NullClaw Nexus Web UI

**What you can do:**
- Everything from Option 1
- ✅ AI chat with configured providers
- ✅ Agent interactions
- ✅ Tool calling

**Requirements:**
- NullClaw binary built at: `../nullclaw/zig-out/bin/nullclaw.exe`
- API key for your chosen provider (OpenAI, Claude, etc.)

**When to use:**
- Want full functionality
- Have NullClaw binary
- Using cloud LLM providers

**How to start:**
```cmd
Double-click: start-with-gateway.bat
```

---

## Option 3: Full Stack (UI + Gateway + Ollama)

**File:** `start-with-ollama.bat`

**What it starts:**
- ✅ Ollama (local LLM server)
- ✅ NullClaw Gateway (backend)
- ✅ NullClaw Nexus Web UI

**What you can do:**
- Everything from Option 2
- ✅ 100% local/offline AI
- ✅ No API keys needed
- ✅ Privacy-focused

**Requirements:**
- Ollama installed: https://ollama.com
- NullClaw binary built
- Model pulled: `ollama pull llama3.1`

**When to use:**
- Want complete local setup
- Privacy concerns
- No internet/API costs
- Testing on edge devices

**How to start:**
```cmd
Double-click: start-with-ollama.bat
```

---

## Building NullClaw Binary

If you don't have the NullClaw binary yet:

### Prerequisites:
- Zig 0.15+ installed: https://ziglang.org/download/

### Steps:
```bash
# 1. Clone the repo (in parent directory)
cd ..
git clone https://github.com/nullclaw/nullclaw.git
cd nullclaw

# 2. Build
zig build -Doptimize=ReleaseSmall

# 3. Verify
./zig-out/bin/nullclaw --version
```

The binary will be at: `nullclaw/zig-out/bin/nullclaw.exe`

---

## Installing Ollama

### Windows:
1. Download from: https://ollama.com/download
2. Run installer
3. Open terminal and run:
   ```cmd
   ollama pull llama3.1
   ```

### Verify:
```cmd
ollama list
```

---

## Troubleshooting

### "NullClaw binary not found"
- Build NullClaw first (see above)
- Or use `start.bat` for UI-only mode

### "Ollama not found"
- Install Ollama (see above)
- Or use `start-with-gateway.bat` instead

### "Port already in use"
- Close other instances
- Or change ports in the scripts

### Gateway won't connect
- Check if gateway is running: http://127.0.0.1:3000/health
- Check firewall settings
- Verify binary path in script

---

## Manual Startup (Advanced)

If you prefer manual control:

### Terminal 1 - Ollama (optional):
```cmd
ollama serve
```

### Terminal 2 - NullClaw Gateway:
```cmd
cd ..\nullclaw
.\zig-out\bin\nullclaw gateway --bind 127.0.0.1:3000
```

### Terminal 3 - UI:
```cmd
cd nullclaw-nexus
npm run dev
```

Then open: http://localhost:5173

---

## Recommended Setup

**For Development:**
- Use `start.bat` (UI only)
- Start gateway manually when needed

**For Full Testing:**
- Use `start-with-ollama.bat`
- Everything runs automatically

**For Production:**
- Build UI: `npm run build`
- Deploy static files
- Run gateway as service
