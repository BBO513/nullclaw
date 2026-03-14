# 🤖 Model Selection Guide

## How It Works

NullClaw Nexus lets you choose which AI model to use for chat. The model selection is in **Settings**.

## Steps to Choose Your Model

1. **Open Settings** (⚙️ from dashboard)
2. **Select Provider** (Ollama, OpenAI, Claude, etc.)
3. **Select Model** from the dropdown
4. **Click "Save Settings"**
5. Go to Chat - your selected model is now active!

## Provider Options

### 🏠 Ollama (Local - Recommended)
**Pros:**
- 100% free
- Runs locally (privacy)
- No API keys needed
- Works offline

**Available Models:**
- llama3.1, llama3.2, llama2
- mistral, mixtral
- phi3, gemma2
- qwen2.5
- codellama, deepseek-coder
- neural-chat, starling-lm

**How to get models:**
```bash
ollama pull llama3.1
ollama pull mistral
ollama pull codellama
```

**Check installed models:**
```bash
ollama list
```

The UI will automatically detect and show your installed models!

### ☁️ OpenAI
**Models:**
- gpt-4o (latest, best)
- gpt-4o-mini (fast, cheap)
- gpt-4-turbo
- gpt-4
- gpt-3.5-turbo

**Requires:** API key from https://platform.openai.com

### 🧠 Claude (Anthropic)
**Models:**
- claude-3-5-sonnet-20241022 (best)
- claude-3-5-haiku-20241022 (fast)
- claude-3-opus-20240229
- claude-3-sonnet-20240229
- claude-3-haiku-20240307

**Requires:** API key from https://console.anthropic.com

### ⚡ Other Providers
- **Groq** - Ultra-fast inference
- **Together AI** - Open models
- **OpenRouter** - Access to many models
- **Cohere** - Enterprise AI
- **Mistral AI** - European AI
- **Perplexity** - Search-enhanced
- **DeepSeek** - Coding specialist

## Model Selection in Action

### In Settings:
```
Provider: [Ollama ⭐]
Model: [llama3.1] (12 installed)
```

### In Chat Header:
```
Model: llama3.1
```

## Switching Models

You can switch models anytime:
1. Go to Settings
2. Change the model dropdown
3. Save
4. Return to Chat
5. New messages use the new model!

## Tips

### For Coding:
- `codellama` (Ollama)
- `deepseek-coder` (Ollama)
- `gpt-4o` (OpenAI)

### For Speed:
- `llama3.2` (Ollama - small)
- `phi3` (Ollama - tiny)
- `gpt-4o-mini` (OpenAI)
- `claude-3-5-haiku` (Claude)

### For Quality:
- `llama3.1` (Ollama - best local)
- `gpt-4o` (OpenAI - best overall)
- `claude-3-5-sonnet` (Claude - best reasoning)

### For Privacy:
- Any Ollama model (runs locally)

## Troubleshooting

### "No models found" (Ollama)
Pull a model first:
```bash
ollama pull llama3.1
```

### Model not responding
- Check if Ollama is running: `ollama serve`
- Check gateway connection in Settings
- Verify model is installed: `ollama list`

### Wrong model responding
- Check Settings → Model dropdown
- Click "Save Settings"
- Refresh chat page

## Technical Details

The model name is sent in the API request:
```json
{
  "model": "llama3.1",
  "messages": [...],
  "stream": true
}
```

For Ollama, this goes to: `http://localhost:11434/v1/chat/completions`

For other providers, it goes through the NullClaw gateway which routes to the appropriate API.

## Future Enhancements

Coming soon:
- [ ] Model parameters (temperature, top_p)
- [ ] Context length settings
- [ ] Model comparison mode
- [ ] Cost tracking (for paid APIs)
- [ ] Model performance stats
