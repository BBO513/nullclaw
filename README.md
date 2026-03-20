# NullClaw

Ultra-lightweight autonomous AI agent runtime built in Zig.

## 🎯 Overview

NullClaw is a minimal, blazing-fast AI agent runtime designed for edge devices and resource-constrained environments:

- **678 KB binary** - Tiny footprint
- **~1 MB RAM** - Minimal memory usage
- **<2 ms boot time** - Instant startup
- **Multi-platform** - Linux, macOS, Windows, ARM, RISC-V

## 🚀 Features

- **Gateway Mode** - OpenAI-compatible REST API (`/v1/chat/completions`)
- **Multi-Provider Support** - Ollama, OpenAI, Claude, Groq, and 22+ LLM providers
- **Agent Runtime** - Autonomous agent execution with tool calling
- **Memory System** - Persistent memory and knowledge injection
- **WebSocket Support** - Real-time streaming responses
- **WhatsApp Channel** - Direct WhatsApp integration
- **Lane Queues** - Efficient message processing
- **Event Bus** - Modular event-driven architecture

## 🛠️ Building

### Prerequisites

- Zig 0.13+ ([download here](https://ziglang.org/download/))

### Build Commands

```bash
# Clone the repository
git clone https://github.com/BBO513/nullclaw.git
cd nullclaw

# Build optimized binary
zig build -Doptimize=ReleaseSmall

# Binary location: ./zig-out/bin/nullclaw
```

## 🏃 Running

### Gateway Mode

Start the HTTP gateway server:

```bash
./zig-out/bin/nullclaw gateway --bind 127.0.0.1:3000
```

Or bind to all interfaces:

```bash
./zig-out/bin/nullclaw gateway --bind 0.0.0.0:3000
```

### Configuration

Edit `config.json` to configure:
- LLM providers (Ollama, OpenAI, etc.)
- API keys and endpoints
- Memory paths
- Tool configurations

Example `config.json`:
```json
{
  "provider": "ollama",
  "api_base": "http://localhost:11434",
  "model": "llama3.1",
  "memory_path": "./memory"
}
```

## 📡 API Endpoints

### Health Check
```bash
curl http://localhost:3000/health
```

### Chat Completion (OpenAI-compatible)
```bash
curl -X POST http://localhost:3000/v1/chat/completions \
  -H "Content-Type: application/json" \
  -d '{
    "model": "llama3.1",
    "messages": [{"role": "user", "content": "Hello!"}],
    "stream": true
  }'
```

## 🔗 Integration

NullClaw is designed to work with [NullClaw Nexus](https://github.com/BBO513/nullclaw-nexus) - the web UI control center.

## 🏗️ Project Structure

```
nullclaw/
├── src/
│   ├── gateway.zig          # HTTP gateway server
│   ├── agent.zig            # Agent runtime
│   ├── session.zig          # Session management
│   ├── providers/           # LLM provider integrations
│   ├── channels/            # Communication channels (WhatsApp, etc.)
│   ├── memory/              # Memory system
│   └── tools/               # Tool calling system
├── build.zig                # Build configuration
├── build.zig.zon            # Dependencies
└── config.json              # Runtime configuration
```

## 🤖 Ollama Setup

For local LLM support:

1. Install Ollama: https://ollama.com
2. Pull a model: `ollama pull llama3.1`
3. Run: `ollama serve`
4. Configure NullClaw to use Ollama endpoint

## 🐧 Systemd Service

Install as a system service on Linux:

```bash
sudo cp nullclaw.service /etc/systemd/system/
sudo systemctl daemon-reload
sudo systemctl enable nullclaw
sudo systemctl start nullclaw
```

## 📦 Deployment

### Edge Devices
- Raspberry Pi (ARM)
- Low-power ARM boards
- STM32 microcontrollers
- x86/x64 servers

### Cloud
- Docker containers
- Kubernetes pods
- Serverless functions

## 🔧 Development

### Run Tests
```bash
zig build test
```

### Debug Build
```bash
zig build
```

## 📄 License

MIT

## 🙏 Credits

Based on the upstream [NullClaw project](https://github.com/nullclaw/nullclaw).
