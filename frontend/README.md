# NullClaw Nexus

Ultra-lightweight AI Agent Control Center for NullClaw

## 🌐 Live Demo

**Try it now:** [https://nullclawnexus.com](https://nullclawnexus.com) *(deployment pending)*

No installation required - works in your browser! Install as a PWA for offline support.

---

## 🚀 Features

- **Setup Wizard** - Guided onboarding for first-time users (6 easy steps)
- **Live Chat** - Real-time streaming conversations with AI agents
- **Memory Vault** - Upload, edit, and inject prompts & knowledge files
- **Swarm Forge** - Visual canvas for orchestrating multi-agent swarms
- **Settings** - Configure LLM providers (Ollama + 22 providers)
- **Dark Nebula Theme** - Cyber-futuristic UI with indigo/blue-purple accents
- **Progressive Web App** - Install on desktop & mobile, works offline
- **Secure Authentication** - Bearer token pairing with NullClaw gateway

## 🎯 First-Time Setup

### Automatic Setup Wizard

On first launch, NullClaw Nexus will guide you through a 6-step setup wizard:

1. **Welcome** - Introduction and overview
2. **Gateway Connection** - Connect to NullClaw gateway
3. **Pairing** - Secure authentication with bearer token
4. **Provider Selection** - Choose your AI provider (Ollama, OpenAI, Claude, etc.)
5. **Model Selection** - Select your preferred model
6. **License Activation** - Optional: Activate pro license or use free tier

**Re-run anytime:** Settings → "🚀 Run Setup Wizard"

### Manual Setup (Advanced)

If you prefer manual configuration:
1. Start NullClaw gateway: `./nullclaw gateway`
2. Open NullClaw Nexus
3. Go to Settings
4. Configure gateway URL, provider, and model
5. Pair with gateway using 6-digit code

## 📱 Progressive Web App

NullClaw Nexus is a full-featured PWA:
- ✅ **Installable** - Add to home screen on mobile, install as app on desktop
- ✅ **Offline Support** - UI cached for offline access
- ✅ **Fast** - Service worker caching for instant loads
- ✅ **Responsive** - Works on all devices and screen sizes

## 📋 Prerequisites

- Node.js v20+ (installed ✅)
- NullClaw binary (optional, for gateway connection)
- Ollama (optional, for local LLM)

## 🛠️ Development

### Start the dev server:

```powershell
.\start-dev.ps1
```

Or manually:

```powershell
npm run dev
```

The app will open at `http://localhost:5173`

### Build for production:

```powershell
npm run build
```

### Preview production build:

```powershell
npm run preview
```

## 🌍 Deployment

### Quick Deploy to Vercel:

```bash
npm install -g vercel
npm run build
vercel --prod
```

See [PWA_DEPLOYMENT_GUIDE.md](PWA_DEPLOYMENT_GUIDE.md) for detailed instructions.

### Supported Platforms:
- ✅ Vercel (recommended)
- ✅ Netlify
- ✅ Cloudflare Pages
- ✅ GitHub Pages
- ✅ Any static host

## 🔧 Project Structure

```
nullclaw-nexus/
├── src/
│   ├── lib/
│   │   ├── components/     # UI components
│   │   ├── stores/         # Svelte stores (agents, memories, theme)
│   │   ├── api/            # Gateway API client
│   │   └── utils/          # Utilities
│   ├── routes/
│   │   ├── +page.svelte          # Dashboard
│   │   ├── chat/+page.svelte     # Live Chat
│   │   ├── swarm/+page.svelte    # Swarm Forge
│   │   ├── memory/+page.svelte   # Memory Vault
│   │   └── settings/+page.svelte # Settings
│   └── app.css             # Nebula theme styles
├── static/                 # Static assets
└── tailwind.config.js      # Tailwind configuration
```

## 🎨 Theme

The Nebula theme features:
- Primary: `#7c3aed` (indigo)
- Accent: `#00f0ff` (cyan glow)
- Secondary: `#c084fc` (purple)
- Glassmorphism effects
- Smooth animations

## 📦 Tech Stack

- **SvelteKit 5** - Framework
- **Tailwind CSS** - Styling
- **SvelteFlow** - Swarm canvas
- **TypeScript** - Type safety

## 🔗 NullClaw Gateway

To connect to NullClaw:

1. Build NullClaw binary:
```bash
git clone https://github.com/nullclaw/nullclaw.git
cd nullclaw
zig build -Doptimize=ReleaseSmall
```

2. Run gateway:
```bash
./zig-out/bin/nullclaw gateway --bind 127.0.0.1:3000
```

3. Configure in Settings page

## 🤖 Ollama Setup

For local LLM support:

1. Install Ollama: https://ollama.com
2. Pull a model: `ollama pull llama3.1`
3. Run: `ollama serve`

## 📱 Next Steps

- [ ] Add Monaco editor for memory editing
- [ ] Implement tool timeline & approvals
- [ ] Add Tauri desktop wrapper
- [ ] Add Capacitor mobile wrapper
- [ ] Implement IAP for mobile
- [ ] Add more themes (Void, Eclipse)
- [ ] Export swarm configurations
- [ ] Real-time agent status updates

## 📄 License

MIT

## 🙏 Credits

Built for the NullClaw community
