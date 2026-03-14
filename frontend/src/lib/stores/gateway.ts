import { writable } from 'svelte/store';
import { discoverGateway, isTauri } from '$lib/tauri';

export interface GatewayHealthStatus {
  connected: boolean;
  latency: number;
  lastChecked: Date;
}

export const gatewayStatus = writable<GatewayHealthStatus>({
  connected: false,
  latency: 0,
  lastChecked: new Date()
});

/**
 * Check gateway health and update the gatewayStatus store.
 * Called from OfflineIndicator on a 15-second interval.
 */
export async function checkGatewayHealth(url: string): Promise<boolean> {
  const start = Date.now();
  try {
    const res = await fetch(`${url}/health`, { signal: AbortSignal.timeout(5000) });
    if (res.ok) {
      gatewayStatus.set({
        connected: true,
        latency: Date.now() - start,
        lastChecked: new Date()
      });
      return true;
    }
  } catch {
    // Gateway unreachable
  }
  gatewayStatus.set({ connected: false, latency: 0, lastChecked: new Date() });
  return false;
}

export interface GatewayConfig {
  url: string;
  connected: boolean;
  provider: string;
  model: string;
  bearerToken: string | null;
  paired: boolean;
}

// Default gateway URL — in Tauri, auto-discovery will override this
const DEFAULT_GATEWAY_URL = 'http://127.0.0.1:3000';

// Load from localStorage if available
function loadGatewayConfig(): GatewayConfig {
  const defaultConfig: GatewayConfig = {
    url: DEFAULT_GATEWAY_URL,
    connected: false,
    provider: 'ollama',
    model: 'llama3.1',
    bearerToken: null,
    paired: false
  };

  if (typeof localStorage === 'undefined') {
    return defaultConfig;
  }

  try {
    const stored = localStorage.getItem('gatewayConfig');
    if (!stored) {
      return defaultConfig;
    }
    
    const config = JSON.parse(stored);
    return config;
  } catch (error) {
    console.error('Failed to load gateway config from localStorage:', error);
    return defaultConfig;
  }
}

/**
 * Auto-discover gateway URL by probing known ports.
 * Called from layout on mount. Updates the store if a gateway is found.
 */
export async function autoDiscoverGateway(): Promise<string | null> {
  try {
    const url = await discoverGateway();
    if (url) {
      console.log('[Gateway] Auto-discovered gateway at:', url);
      gatewayConfig.update(c => ({ ...c, url, connected: true }));
      return url;
    }
  } catch (e) {
    console.warn('[Gateway] Auto-discovery failed:', e);
  }
  return null;
}

const initial: GatewayConfig = loadGatewayConfig();

// Svelte 5 compatible store with auto-subscription support
export const gatewayConfig = writable<GatewayConfig>(initial);

// Persist to localStorage on changes
gatewayConfig.subscribe(value => {
  if (typeof localStorage !== 'undefined') {
    try {
      localStorage.setItem('gatewayConfig', JSON.stringify(value));
    } catch (error) {
      console.error('Failed to save gateway config to localStorage:', error);
    }
  }
});

export const providers = [
  { id: 'ollama', name: 'Ollama (Local)', priority: true },
  { id: 'openai', name: 'OpenAI' },
  { id: 'anthropic', name: 'Claude (Anthropic)' },
  { id: 'groq', name: 'Groq' },
  { id: 'together', name: 'Together AI' },
  { id: 'openrouter', name: 'OpenRouter' },
  { id: 'cohere', name: 'Cohere' },
  { id: 'mistral', name: 'Mistral AI' },
  { id: 'perplexity', name: 'Perplexity' },
  { id: 'deepseek', name: 'DeepSeek' },
  { id: 'google', name: 'Google AI (Gemini)' },
  { id: 'azure', name: 'Azure OpenAI' },
  { id: 'huggingface', name: 'Hugging Face' },
  { id: 'replicate', name: 'Replicate' },
  { id: 'anyscale', name: 'Anyscale' },
  { id: 'fireworks', name: 'Fireworks AI' },
  { id: 'deepinfra', name: 'DeepInfra' },
  { id: 'lepton', name: 'Lepton AI' },
  { id: 'octoai', name: 'OctoAI' },
  { id: 'novita', name: 'Novita AI' },
  { id: 'cerebras', name: 'Cerebras' },
  { id: 'sambanova', name: 'SambaNova' },
  { id: 'custom', name: 'Custom Endpoint' },
];

// Common Ollama models
export const ollamaModels = [
  'llama3.1',
  'llama3.2',
  'llama2',
  'mistral',
  'mixtral',
  'phi3',
  'gemma2',
  'qwen2.5',
  'codellama',
  'deepseek-coder',
  'neural-chat',
  'starling-lm',
];

// OpenAI models
export const openaiModels = [
  'gpt-4o',
  'gpt-4o-mini',
  'gpt-4-turbo',
  'gpt-4',
  'gpt-3.5-turbo',
];

// Claude models
export const claudeModels = [
  'claude-3-5-sonnet-20241022',
  'claude-3-5-haiku-20241022',
  'claude-3-opus-20240229',
  'claude-3-sonnet-20240229',
  'claude-3-haiku-20240307',
];
