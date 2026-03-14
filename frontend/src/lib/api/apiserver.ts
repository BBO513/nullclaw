/**
 * NullClaw API Server Client
 * 
 * Connects to the separate API server (port 3334) for agent/swarm/memory management.
 * This is separate from the gateway (port 3333) which handles WhatsApp integration.
 * 
 * ENDPOINTS:
 * - GET  /api/agents                - List all agents
 * - POST /api/agents                - Create new agent
 * - GET  /api/swarms                - List all swarms
 * - POST /api/swarms                - Create new swarm
 * - GET  /api/memory                - List all memory files
 * - POST /api/memory                - Upload memory file
 */

export interface Agent {
  id: string;
  name: string;
  model: string;
  status: 'active' | 'paused' | 'failed';
  created_at: number;
}

export interface Swarm {
  id: string;
  name: string;
  agents: string[]; // agent IDs
}

export interface MemoryFile {
  id: string;
  name: string;
  size: number;
  uploaded_at: number;
  path: string;
}

export class APIServerClient {
  private baseUrl: string;
  private bearerToken: string | null;

  constructor(baseUrl: string = 'http://127.0.0.1:3334', bearerToken: string | null = null) {
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

  // ============================================================================
  // AGENTS
  // ============================================================================

  async getAgents(): Promise<Agent[]> {
    try {
      const response = await fetch(`${this.baseUrl}/api/agents`, {
        headers: this.getHeaders(),
        signal: AbortSignal.timeout(5000),
      });

      if (!response.ok) {
        if (response.status === 401) {
          throw new Error('Unauthorized: Please pair with gateway first');
        }
        throw new Error(`Failed to fetch agents: ${response.statusText}`);
      }

      return await response.json();
    } catch (error) {
      console.error('Error fetching agents:', error);
      throw error;
    }
  }

  async createAgent(name: string, model: string): Promise<Agent> {
    try {
      const response = await fetch(`${this.baseUrl}/api/agents`, {
        method: 'POST',
        headers: this.getHeaders(),
        body: JSON.stringify({ name, model }),
        signal: AbortSignal.timeout(5000),
      });

      if (!response.ok) {
        if (response.status === 401) {
          throw new Error('Unauthorized: Please pair with gateway first');
        }
        throw new Error(`Failed to create agent: ${response.statusText}`);
      }

      return await response.json();
    } catch (error) {
      console.error('Error creating agent:', error);
      throw error;
    }
  }

  // ============================================================================
  // SWARMS
  // ============================================================================

  async getSwarms(): Promise<Swarm[]> {
    try {
      const response = await fetch(`${this.baseUrl}/api/swarms`, {
        headers: this.getHeaders(),
        signal: AbortSignal.timeout(5000),
      });

      if (!response.ok) {
        if (response.status === 401) {
          throw new Error('Unauthorized: Please pair with gateway first');
        }
        throw new Error(`Failed to fetch swarms: ${response.statusText}`);
      }

      return await response.json();
    } catch (error) {
      console.error('Error fetching swarms:', error);
      throw error;
    }
  }

  async createSwarm(name: string): Promise<Swarm> {
    try {
      const response = await fetch(`${this.baseUrl}/api/swarms`, {
        method: 'POST',
        headers: this.getHeaders(),
        body: JSON.stringify({ name }),
        signal: AbortSignal.timeout(5000),
      });

      if (!response.ok) {
        if (response.status === 401) {
          throw new Error('Unauthorized: Please pair with gateway first');
        }
        throw new Error(`Failed to create swarm: ${response.statusText}`);
      }

      return await response.json();
    } catch (error) {
      console.error('Error creating swarm:', error);
      throw error;
    }
  }

  // ============================================================================
  // MEMORY
  // ============================================================================

  async getMemoryFiles(): Promise<MemoryFile[]> {
    try {
      const response = await fetch(`${this.baseUrl}/api/memory`, {
        headers: this.getHeaders(),
        signal: AbortSignal.timeout(5000),
      });

      if (!response.ok) {
        if (response.status === 401) {
          throw new Error('Unauthorized: Please pair with gateway first');
        }
        throw new Error(`Failed to fetch memory files: ${response.statusText}`);
      }

      return await response.json();
    } catch (error) {
      console.error('Error fetching memory files:', error);
      throw error;
    }
  }

  async uploadMemoryFile(name: string, content: string): Promise<MemoryFile> {
    try {
      const response = await fetch(`${this.baseUrl}/api/memory`, {
        method: 'POST',
        headers: this.getHeaders(),
        body: JSON.stringify({ name, content }),
        signal: AbortSignal.timeout(10000), // Longer timeout for uploads
      });

      if (!response.ok) {
        if (response.status === 401) {
          throw new Error('Unauthorized: Please pair with gateway first');
        }
        throw new Error(`Failed to upload memory file: ${response.statusText}`);
      }

      return await response.json();
    } catch (error) {
      console.error('Error uploading memory file:', error);
      throw error;
    }
  }
}
