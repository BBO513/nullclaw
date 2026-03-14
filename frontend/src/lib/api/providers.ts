/**
 * Unified LLM Provider API Client
 * Supports 22+ providers with OpenAI-compatible interface
 */

export interface Message {
  role: 'user' | 'assistant' | 'system';
  content: string;
}

export interface ChatRequest {
  model: string;
  messages: Message[];
  stream?: boolean;
  temperature?: number;
  max_tokens?: number;
}

export interface ProviderConfig {
  apiKey?: string;
  baseUrl?: string;
  organization?: string;
}

/**
 * Provider base URLs and configurations
 */
const PROVIDER_CONFIGS: Record<string, { baseUrl: string; requiresKey: boolean }> = {
  openai: { baseUrl: 'https://api.openai.com/v1', requiresKey: true },
  anthropic: { baseUrl: 'https://api.anthropic.com/v1', requiresKey: true },
  groq: { baseUrl: 'https://api.groq.com/openai/v1', requiresKey: true },
  together: { baseUrl: 'https://api.together.xyz/v1', requiresKey: true },
  openrouter: { baseUrl: 'https://openrouter.ai/api/v1', requiresKey: true },
  cohere: { baseUrl: 'https://api.cohere.ai/v1', requiresKey: true },
  mistral: { baseUrl: 'https://api.mistral.ai/v1', requiresKey: true },
  perplexity: { baseUrl: 'https://api.perplexity.ai', requiresKey: true },
  deepseek: { baseUrl: 'https://api.deepseek.com/v1', requiresKey: true },
  google: { baseUrl: 'https://generativelanguage.googleapis.com/v1', requiresKey: true },
  azure: { baseUrl: '', requiresKey: true }, // Custom per deployment
  huggingface: { baseUrl: 'https://api-inference.huggingface.co/models', requiresKey: true },
  replicate: { baseUrl: 'https://api.replicate.com/v1', requiresKey: true },
  anyscale: { baseUrl: 'https://api.endpoints.anyscale.com/v1', requiresKey: true },
  fireworks: { baseUrl: 'https://api.fireworks.ai/inference/v1', requiresKey: true },
  deepinfra: { baseUrl: 'https://api.deepinfra.com/v1/openai', requiresKey: true },
  lepton: { baseUrl: 'https://api.lepton.ai/api/v1', requiresKey: true },
  octoai: { baseUrl: 'https://text.octoai.run/v1', requiresKey: true },
  novita: { baseUrl: 'https://api.novita.ai/v3/openai', requiresKey: true },
  cerebras: { baseUrl: 'https://api.cerebras.ai/v1', requiresKey: true },
  sambanova: { baseUrl: 'https://api.sambanova.ai/v1', requiresKey: true },
  custom: { baseUrl: '', requiresKey: false },
};

export class ProviderAPI {
  private provider: string;
  private config: ProviderConfig;

  constructor(provider: string, config: ProviderConfig = {}) {
    this.provider = provider;
    this.config = config;
  }

  private getBaseUrl(): string {
    if (this.config.baseUrl) {
      return this.config.baseUrl;
    }
    return PROVIDER_CONFIGS[this.provider]?.baseUrl || '';
  }

  private getHeaders(): HeadersInit {
    const headers: HeadersInit = {
      'Content-Type': 'application/json',
    };

    if (this.config.apiKey) {
      // Different providers use different auth headers
      switch (this.provider) {
        case 'anthropic':
          headers['x-api-key'] = this.config.apiKey;
          headers['anthropic-version'] = '2023-06-01';
          break;
        case 'cohere':
          headers['Authorization'] = `Bearer ${this.config.apiKey}`;
          break;
        case 'huggingface':
          headers['Authorization'] = `Bearer ${this.config.apiKey}`;
          break;
        default:
          // OpenAI-compatible (most providers)
          headers['Authorization'] = `Bearer ${this.config.apiKey}`;
      }
    }

    if (this.config.organization) {
      headers['OpenAI-Organization'] = this.config.organization;
    }

    return headers;
  }

  async *chat(request: ChatRequest): AsyncGenerator<string> {
    const baseUrl = this.getBaseUrl();
    if (!baseUrl) {
      throw new Error(`Provider ${this.provider} requires a base URL`);
    }

    const requiresKey = PROVIDER_CONFIGS[this.provider]?.requiresKey;
    if (requiresKey && !this.config.apiKey) {
      throw new Error(`Provider ${this.provider} requires an API key`);
    }

    try {
      // Anthropic uses different format
      if (this.provider === 'anthropic') {
        yield* this.chatAnthropic(request);
        return;
      }

      // OpenAI-compatible format (most providers)
      const response = await fetch(`${baseUrl}/chat/completions`, {
        method: 'POST',
        headers: this.getHeaders(),
        body: JSON.stringify({
          model: request.model,
          messages: request.messages,
          stream: true,
          temperature: request.temperature,
          max_tokens: request.max_tokens,
        }),
      });

      if (!response.ok) {
        const error = await response.text();
        throw new Error(`${this.provider} error: ${response.statusText} - ${error}`);
      }

      const reader = response.body?.getReader();
      const decoder = new TextDecoder();

      if (!reader) {
        throw new Error('Response body is not readable');
      }

      while (true) {
        const { done, value } = await reader.read();
        if (done) break;

        const chunk = decoder.decode(value);
        const lines = chunk.split('\n').filter(line => line.trim().startsWith('data:'));

        for (const line of lines) {
          const data = line.replace(/^data: /, '').trim();
          if (data === '[DONE]') return;

          try {
            const parsed = JSON.parse(data);
            const content = parsed.choices?.[0]?.delta?.content;
            if (content) {
              yield content;
            }
          } catch (e) {
            // Skip invalid JSON
          }
        }
      }
    } catch (error) {
      if (error instanceof Error) {
        throw error;
      }
      throw new Error('An unexpected error occurred');
    }
  }

  private async *chatAnthropic(request: ChatRequest): AsyncGenerator<string> {
    const baseUrl = this.getBaseUrl();
    
    // Convert messages to Anthropic format
    const systemMessage = request.messages.find(m => m.role === 'system');
    const messages = request.messages.filter(m => m.role !== 'system');

    const response = await fetch(`${baseUrl}/messages`, {
      method: 'POST',
      headers: this.getHeaders(),
      body: JSON.stringify({
        model: request.model,
        messages: messages,
        system: systemMessage?.content,
        stream: true,
        max_tokens: request.max_tokens || 4096,
        temperature: request.temperature,
      }),
    });

    if (!response.ok) {
      const error = await response.text();
      throw new Error(`Anthropic error: ${response.statusText} - ${error}`);
    }

    const reader = response.body?.getReader();
    const decoder = new TextDecoder();

    if (!reader) {
      throw new Error('Response body is not readable');
    }

    while (true) {
      const { done, value } = await reader.read();
      if (done) break;

      const chunk = decoder.decode(value);
      const lines = chunk.split('\n').filter(line => line.trim().startsWith('data:'));

      for (const line of lines) {
        const data = line.replace(/^data: /, '').trim();

        try {
          const parsed = JSON.parse(data);
          if (parsed.type === 'content_block_delta') {
            const content = parsed.delta?.text;
            if (content) {
              yield content;
            }
          }
        } catch (e) {
          // Skip invalid JSON
        }
      }
    }
  }

  async sendMessage(request: ChatRequest): Promise<string> {
    let fullResponse = '';
    for await (const chunk of this.chat(request)) {
      fullResponse += chunk;
    }
    return fullResponse;
  }

  static requiresApiKey(provider: string): boolean {
    return PROVIDER_CONFIGS[provider]?.requiresKey ?? false;
  }

  static getProviderConfig(provider: string) {
    return PROVIDER_CONFIGS[provider];
  }
}
