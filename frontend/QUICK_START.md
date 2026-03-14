# Quick Start Guide

## 🚀 Start the Development Server

### Option 1: Using Windows Command Prompt
1. Open a new Command Prompt (cmd)
2. Navigate to the project:
   ```cmd
   cd C:\Users\works\textnullclaw_nexus\nullclaw-nexus
   ```
3. Run:
   ```cmd
   npm run dev
   ```

### Option 2: Using PowerShell
1. Open a new PowerShell window
2. Navigate to the project:
   ```powershell
   cd C:\Users\works\textnullclaw_nexus\nullclaw-nexus
   ```
3. Run:
   ```powershell
   npm run dev
   ```

### Option 3: Double-click the batch file
1. Navigate to: `C:\Users\works\textnullclaw_nexus\nullclaw-nexus`
2. Double-click `start.bat`

## 📱 Access the App

Once the server starts, you'll see:
```
VITE v7.x.x  ready in xxx ms

➜  Local:   http://localhost:5173/
➜  Network: use --host to expose
```

Open your browser and go to: **http://localhost:5173**

## 🛑 Stop the Server

Press `Ctrl + C` in the terminal window

## ✅ What You'll See

- **Dashboard** - Main navigation with stats
- **Live Chat** - AI conversation interface
- **Memory Vault** - File upload and management
- **Swarm Forge** - Visual agent orchestration
- **Settings** - Configure providers and gateway

## 🔧 Troubleshooting

### Port already in use?
If port 5173 is busy, Vite will automatically use the next available port (5174, 5175, etc.)

### Can't connect to gateway?
The gateway connection will show "Disconnected" until you:
1. Build and run the NullClaw binary
2. Start it in gateway mode: `./nullclaw gateway --bind 127.0.0.1:3000`
3. Configure the URL in Settings

### Ollama not detected?
1. Install Ollama from https://ollama.com
2. Run `ollama serve` in a terminal
3. Pull a model: `ollama pull llama3.1`

## 📝 Notes

- The app works without NullClaw gateway (UI only mode)
- You can explore all features even without backend connection
- Gateway is only needed for actual AI chat functionality
