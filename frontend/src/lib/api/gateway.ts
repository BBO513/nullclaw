/**
 * NullClaw Gateway API Client
 * 
 * ACTUAL GATEWAY ENDPOINTS (as of March 2026):
 * - GET  /health                    - Health check (no auth)
 * - POST /pair                      - Exchange pairing code for bearer token
 * - POST /v1/chat/completions       - OpenAI-compatible chat endpoint (requires auth)
 * - GET  /whatsapp                  - Meta webhook verification
 * - POST /whatsapp                  - WhatsApp inbound messages
 * 
 * PLACEHOLDER/FUTURE ENDPOINTS:
 * - POST /config/swarm              - Apply swarm configuration (not yet implemented)
 * 
 * This client uses /v1/chat/completions for all message-based operations and gracefully
 * handles 404 responses for future endpoints.
 */

export interface GatewayStatus {
  status: string;
  version: string;
  uptime_seconds: number;
  provider: {
    type: string;
    base_url: string;
    model: string;
    has_api_key: boolean;
  };
}

export interface ProviderUpdateRequest {
  type: string;
  base_url: string;
  model: string;
  api_key?: string;
}

export interface ChatMessage {
  role: 'user' | 'assistant' | 'system';
  content: string;
}

export interface ChatCompletionRequest {
  model: string;
  messages: ChatMessage[];
  stream?: boolean;
  temperature?: number;
}

export class GatewayAPI {
  private baseUrl: string;
  private bearerToken: string | null;

  constructor(baseUrl: string = 'http://127.0.0.1:3000', bearerToken: string | null = null) {
    this.baseUrl = baseUrl;
    this.bearerToken = bearerToken;
  }

  private getHeaders(): HeadersInit {
    const headers: HeadersInit = {
      'Content-Type': 'application/json',
    };
    if (this.bearerToken) {
      headers['Authorization'] = `Bearer ${this.bearerToken}`;
    }
    return headers;
  }

  async getStatus(): Promise<GatewayStatus | null> {
    try {
      const response = await fetch(`${this.baseUrl}/status`, {
        headers: this.getHeaders(),
        signal: AbortSignal.timeout(5000)
      });
      if (!response.ok) return null;
      return await response.json();
    } catch {
      return null;
    }
  }

  async updateProvider(config: ProviderUpdateRequest): Promise<{ success: boolean; message: string }> {
    try {
      const response = await fetch(`${this.baseUrl}/config/provider`, {
        method: 'POST',
        headers: this.getHeaders(),
        body: JSON.stringify(config),
        signal: AbortSignal.timeout(5000)
      });
      if (!response.ok) {
        const data = await response.json().catch(() => ({ message: response.statusText }));
        return { success: false, message: data.message || `HTTP ${response.status}` };
      }
      const data = await response.json();
      return { success: true, message: data.message || 'Provider updated' };
    } catch (error) {
      const msg = error instanceof Error ? error.message : String(error);
      return { success: false, message: msg };
    }
  }

  async getProviderConfig(): Promise<{ type: string; base_url: string; model: string; has_api_key: boolean } | null> {
    try {
      const response = await fetch(`${this.baseUrl}/config/provider`, {
        headers: this.getHeaders(),
        signal: AbortSignal.timeout(5000)
      });
      if (!response.ok) return null;
      return await response.json();
    } catch {
      return null;
    }
  }

  async checkHealth(): Promise<boolean> {
    try {
      const response = await fetch(`${this.baseUrl}/health`, { 
        signal: AbortSignal.timeout(5000) // 5 second timeout
      });
      return response.ok;
    } catch (error) {
      console.error('Health check failed:', error);
      return false;
    }
  }

  async pairWithMasterKey(masterKey: string): Promise<{ token: string } | null> {
    try {
      const response = await fetch(`${this.baseUrl}/pair-with-master`, {
        method: 'POST',
        headers: { 
          'X-Master-Key': masterKey 
        },
      });
      if (!response.ok) return null;
      const data = await response.json();
      return { token: data.token };
    } catch {
      return null;
    }
  }

  async pair(pairingCode: string): Promise<{ token: string } | null> {
    try {
      // NullClaw gateway expects pairing code in X-Pairing-Code header
      const response = await fetch(`${this.baseUrl}/pair`, {
        method: 'POST',
        headers: { 
          'X-Pairing-Code': pairingCode 
        },
      });
      if (!response.ok) return null;
      const data = await response.json();
      // Handle both response formats: {token: "..."} and {status: "paired", token: "..."}
      return { token: data.token };
    } catch {
      return null;
    }
  }

  async getOllamaModels(): Promise<string[]> {
    try {
      const response = await fetch('http://localhost:11434/api/tags');
      if (!response.ok) return [];
      const data = await response.json();
      return data.models?.map((m: any) => m.name) || [];
    } catch {
      return [];
    }
  }

  async *chatCompletion(request: ChatCompletionRequest): AsyncGenerator<string> {
    try {
      // NullClaw gateway uses /v1/chat/completions endpoint for chat
      const response = await fetch(`${this.baseUrl}/v1/chat/completions`, {
        method: 'POST',
        headers: this.getHeaders(),
        body: JSON.stringify(request),
        signal: AbortSignal.timeout(60000) // 60 second timeout
      });

      if (!response.ok) {
        if (response.status === 401) {
          throw new Error('Unauthorized: Please pair with gateway');
        }
        if (response.status === 429) {
          throw new Error('Rate limit exceeded. Please wait a moment and try again.');
        }
        if (response.status === 404) {
          throw new Error('Chat completions endpoint not found. Please check gateway is running.');
        }
        throw new Error(`Gateway error: ${response.statusText}`);
      }

      // Gateway returns OpenAI-compatible response
      const data = await response.json();
      
      if (data.choices && data.choices[0] && data.choices[0].message) {
        // Stream the reply character by character for smooth display
        const reply = data.choices[0].message.content;
        for (let i = 0; i < reply.length; i++) {
          yield reply[i];
          await new Promise(resolve => setTimeout(resolve, 10));
        }
      } else {
        yield 'No response from gateway.';
      }
    } catch (error) {
      if (error instanceof Error) {
        if (error.name === 'AbortError') {
          throw new Error('Request timed out. Please check your connection and try again.');
        }
        if (error.message.includes('Failed to fetch')) {
          throw new Error('Cannot connect to gateway. Please check that NullClaw is running.');
        }
        throw error;
      }
      throw new Error('An unexpected error occurred');
    }
  }

  async sendMessage(agentId: string, message: string): Promise<{ success: boolean; message?: string }> {
    try {
      // NullClaw gateway uses /v1/chat/completions endpoint for messages
      const response = await fetch(`${this.baseUrl}/v1/chat/completions`, {
        method: 'POST',
        headers: this.getHeaders(),
        body: JSON.stringify({
          model: 'default',
          messages: [{ role: 'user', content: message }]
        }),
        signal: AbortSignal.timeout(60000) // 60 second timeout
      });

      if (!response.ok) {
        if (response.status === 401) {
          throw new Error('Unauthorized: Please pair with gateway');
        }
        if (response.status === 404) {
          throw new Error('Chat completions endpoint not found. Please check gateway is running.');
        }
        throw new Error(`Gateway error: ${response.statusText}`);
      }

      const data = await response.json();
      const reply = data.choices?.[0]?.message?.content || 'Message sent successfully';

      return { 
        success: true, 
        message: reply 
      };
    } catch (error) {
      const errorMsg = error instanceof Error ? error.message : String(error);
      return { 
        success: false, 
        message: errorMsg 
      };
    }
  }

  async injectMemory(model: string, memoryName: string, memoryContent: string): Promise<{ success: boolean; message?: string }> {
    try {
      // Check if memory is too large (>100KB warning, >1MB reject)
      const sizeKB = new Blob([memoryContent]).size / 1024;
      if (sizeKB > 1024) {
        return { 
          success: false, 
          message: `File too large (${sizeKB.toFixed(1)} KB). Maximum size is 1 MB.` 
        };
      }

      // NullClaw gateway uses /v1/chat/completions endpoint
      // Inject memory as a message to establish context
      const response = await fetch(`${this.baseUrl}/v1/chat/completions`, {
        method: 'POST',
        headers: this.getHeaders(),
        body: JSON.stringify({
          model: model || 'default',
          messages: [{
            role: 'user',
            content: `[MEMORY INJECTION] ${memoryName}\n\n${memoryContent}\n\n---\nPlease acknowledge that you have received and understood this memory context.`
          }]
        }),
      });

      if (!response.ok) {
        if (response.status === 401) {
          throw new Error('Unauthorized: Please pair with gateway');
        }
        if (response.status === 404) {
          throw new Error('Chat completions endpoint not found. Please check gateway is running.');
        }
        throw new Error(`Gateway error: ${response.statusText}`);
      }

      // Read response to get acknowledgment
      const data = await response.json();
      const acknowledgment = data.choices?.[0]?.message?.content || 'Memory injected successfully';

      return { 
        success: true, 
        message: acknowledgment 
      };
    } catch (error) {
      const errorMsg = error instanceof Error ? error.message : String(error);
      return { 
        success: false, 
        message: errorMsg 
      };
    }
  }

  async applySwarmConfig(config: any): Promise<{ success: boolean; message?: string }> {
    try {
      // NOTE: /config/swarm is a placeholder/future endpoint
      // NullClaw gateway currently only supports /health, /pair, and /v1/chat/completions
      // This will gracefully fail with 404 and suggest download instead
      const response = await fetch(`${this.baseUrl}/config/swarm`, {
        method: 'POST',
        headers: this.getHeaders(),
        body: JSON.stringify(config),
        signal: AbortSignal.timeout(5000) // 5 second timeout
      });

      if (!response.ok) {
        if (response.status === 401) {
          throw new Error('Unauthorized: Please pair with gateway');
        }
        if (response.status === 404) {
          // Expected: endpoint doesn't exist yet
          throw new Error('ENDPOINT_NOT_AVAILABLE');
        }
        throw new Error(`Gateway error: ${response.statusText}`);
      }

      const data = await response.json();
      return { 
        success: true, 
        message: data.message || 'Swarm config applied successfully' 
      };
    } catch (error) {
      if (error instanceof Error) {
        if (error.message === 'ENDPOINT_NOT_AVAILABLE') {
          return {
            success: false,
            message: 'Gateway does not support swarm config endpoint yet. Config downloaded instead.'
          };
        }
        return { 
          success: false, 
          message: error.message 
        };
      }
      return { 
        success: false, 
        message: String(error) 
      };
    }
  }
}
