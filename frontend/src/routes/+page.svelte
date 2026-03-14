<svelte:options runes={false} />

<script lang="ts">
  import { onMount, onDestroy } from 'svelte';
  import { gatewayConfig } from '$lib/stores/gateway';
  import { GatewayAPI } from '$lib/api/gateway';
  import type { GatewayStatus } from '$lib/api/gateway';
  import PairingModal from '$lib/components/PairingModal.svelte';
  import LicenseModal from '$lib/components/LicenseModal.svelte';
  import LaneMonitoring from '$lib/components/LaneMonitoring.svelte';

  let connected = false;
  let checking = true;
  let fetching = false;
  let showPairing = false;
  let showLicenseModal = false;

  // Live status data
  let gatewayStatus: GatewayStatus | null = null;
  let statusInterval: ReturnType<typeof setInterval> | null = null;

  function closePairing() {
    showPairing = false;
  }

  function closeLicense() {
    showLicenseModal = false;
  }

  function formatUptime(seconds: number): string {
    if (seconds < 60) return `${seconds}s`;
    if (seconds < 3600) return `${Math.floor(seconds / 60)}m ${seconds % 60}s`;
    const hours = Math.floor(seconds / 3600);
    const mins = Math.floor((seconds % 3600) / 60);
    return `${hours}h ${mins}m`;
  }

  async function fetchStatus() {
    if (fetching) return;
    fetching = true;
    try {
      const api = new GatewayAPI($gatewayConfig.url, $gatewayConfig.bearerToken);
      const status = await api.getStatus();
      if (status) {
        gatewayStatus = status;
        connected = true;
        gatewayConfig.update(c => ({ ...c, connected: true }));
      } else {
        // Fall back to health check
        gatewayStatus = null;
        const healthy = await api.checkHealth();
        connected = healthy;
        gatewayConfig.update(c => ({ ...c, connected: healthy }));
      }
    } finally {
      fetching = false;
    }
  }

  onMount(async () => {
    checking = false;

    // Initial status fetch
    await fetchStatus();

    // Poll every 5 seconds
    statusInterval = setInterval(fetchStatus, 5000);
  });

  onDestroy(() => {
    if (statusInterval) {
      clearInterval(statusInterval);
    }
  });
</script>

<PairingModal show={showPairing} onClose={closePairing} />
<LicenseModal show={showLicenseModal} onClose={closeLicense} />

<div class="min-h-screen p-8">
  <div class="max-w-7xl mx-auto">
    <!-- Header -->
    <header class="mb-12">
      <div class="flex items-center justify-between">
        <div>
          <h1 class="text-5xl font-bold bg-gradient-to-r from-nebula-primary via-nebula-accent to-nebula-secondary bg-clip-text text-transparent">
            NullClaw Nexus
          </h1>
          <p class="text-nebula-primaryLight mt-2">Ultra-lightweight AI Agent Control Center</p>
        </div>
        <div class="flex items-center gap-4">
          <div class="glass px-4 py-2 flex items-center gap-2">
            <div class={`w-2 h-2 rounded-full ${connected ? 'bg-green-500' : 'bg-red-500'} animate-pulse`}></div>
            <span class="text-sm">{checking ? 'Checking...' : connected ? 'Connected' : 'Disconnected'}</span>
          </div>
        </div>
      </div>
    </header>

    <!-- Gateway Status Dashboard -->
    <div class="glass p-6 mb-12">
      <div class="flex items-center justify-between mb-4">
        <h2 class="text-2xl font-bold">Gateway Status</h2>
        {#if gatewayStatus}
          <span class="text-xs text-gray-500">Auto-refreshes every 5s</span>
        {/if}
      </div>

      {#if gatewayStatus}
        <div class="grid grid-cols-1 md:grid-cols-4 gap-6">
          <div class="glass p-5 hover:scale-105 transition-all" title="Gateway version and uptime">
            <div class="text-green-400 text-2xl font-bold">v{gatewayStatus.version}</div>
            <div class="text-sm text-gray-400 mt-1">Running</div>
            <div class="text-xs text-gray-500 mt-2">Uptime: {formatUptime(gatewayStatus.uptime_seconds)}</div>
          </div>
          <div class="glass p-5 hover:scale-105 transition-all" title="Active LLM provider">
            <div class="text-nebula-accent text-2xl font-bold capitalize">{gatewayStatus.provider.type}</div>
            <div class="text-sm text-gray-400 mt-1">Provider</div>
            <div class="text-xs text-gray-500 mt-2 truncate" title={gatewayStatus.provider.base_url}>{gatewayStatus.provider.base_url}</div>
          </div>
          <div class="glass p-5 hover:scale-105 transition-all" title="Active model">
            <div class="text-nebula-primary text-2xl font-bold truncate" title={gatewayStatus.provider.model}>{gatewayStatus.provider.model}</div>
            <div class="text-sm text-gray-400 mt-1">Model</div>
          </div>
          <div class="glass p-5 hover:scale-105 transition-all" title="API key status">
            <div class={`text-2xl font-bold ${gatewayStatus.provider.has_api_key ? 'text-green-400' : 'text-yellow-400'}`}>
              {gatewayStatus.provider.has_api_key ? 'Configured' : 'Not Set'}
            </div>
            <div class="text-sm text-gray-400 mt-1">API Key</div>
            {#if !gatewayStatus.provider.has_api_key && gatewayStatus.provider.type !== 'ollama'}
              <a href="/settings" class="text-xs text-nebula-accent hover:underline mt-2 inline-block">Configure in Settings</a>
            {/if}
          </div>
        </div>
      {:else if connected}
        <div class="grid grid-cols-1 md:grid-cols-4 gap-6">
          <div class="glass p-5">
            <div class="text-green-400 text-2xl font-bold">Healthy</div>
            <div class="text-sm text-gray-400 mt-1">Gateway Online</div>
          </div>
          <div class="glass p-5">
            <div class="text-gray-500 text-2xl font-bold">--</div>
            <div class="text-sm text-gray-400 mt-1">Provider</div>
          </div>
          <div class="glass p-5">
            <div class="text-gray-500 text-2xl font-bold">--</div>
            <div class="text-sm text-gray-400 mt-1">Model</div>
          </div>
          <div class="glass p-5">
            <div class="text-gray-500 text-2xl font-bold">--</div>
            <div class="text-sm text-gray-400 mt-1">API Key</div>
          </div>
        </div>
      {:else}
        <div class="text-center py-8">
          <div class="text-red-400 text-xl font-bold mb-2">Gateway Offline</div>
          <p class="text-gray-400 text-sm mb-4">Cannot reach NullClaw gateway at {$gatewayConfig.url}</p>
          <div class="flex items-center justify-center gap-4">
            <a href="/settings" class="px-4 py-2 bg-nebula-primary hover:bg-nebula-primaryLight rounded-lg text-sm font-semibold">
              Check Settings
            </a>
            <p class="text-xs text-gray-500">
              Start the gateway: <code class="bg-nebula-bg px-2 py-1 rounded">./nullclaw serve</code>
            </p>
          </div>
        </div>
      {/if}
    </div>

    <!-- Quick Stats -->
    <div class="grid grid-cols-1 md:grid-cols-4 gap-6 mb-12">
      <div class="glass p-6 cursor-pointer hover:scale-105 hover:shadow-neon transition-all" title="Compiled binary size - ultra-lightweight">
        <div class="text-nebula-accent text-3xl font-bold">3.47 MB</div>
        <div class="text-sm text-gray-400 mt-1">Binary Size</div>
      </div>
      <div class="glass p-6 cursor-pointer hover:scale-105 hover:shadow-neon transition-all" title="Peak memory during operation">
        <div class="text-nebula-primary text-3xl font-bold">~1 MB</div>
        <div class="text-sm text-gray-400 mt-1">RAM Usage</div>
      </div>
      <div class="glass p-6 cursor-pointer hover:scale-105 hover:shadow-neon transition-all" title="Cold start time">
        <div class="text-nebula-secondary text-3xl font-bold">&lt;2 ms</div>
        <div class="text-sm text-gray-400 mt-1">Boot Time</div>
      </div>
      <a href="/settings" class="glass p-6 cursor-pointer hover:scale-105 hover:shadow-neon transition-all">
        <div class="text-nebula-accent text-3xl font-bold">22+</div>
        <div class="text-sm text-gray-400 mt-1">LLM Providers</div>
      </a>
    </div>

    <!-- Lane Queue Monitoring -->
    <div class="mb-12">
      <h2 class="text-2xl font-bold mb-4">Execution Lane Monitoring</h2>
      <p class="text-gray-400 mb-6">Monitor gateway queue status and agent execution lanes for real-time visibility into processing delays.</p>
      <LaneMonitoring />
    </div>

    <!-- Main Navigation Cards -->
    <div class="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-6">
      <a href="/chat" class="glass p-8 hover:border-nebula-primary hover:shadow-neon hover:scale-105 transition-all cursor-pointer group">
        <div class="text-4xl mb-4">💬</div>
        <h3 class="text-2xl font-bold mb-2 group-hover:text-nebula-accent">Live Chat</h3>
        <p class="text-gray-400">Interact with AI agents in real-time with streaming responses</p>
      </a>

      <a href="/swarm" class="glass p-8 hover:border-nebula-primary hover:shadow-neon hover:scale-105 transition-all cursor-pointer group">
        <div class="text-4xl mb-4">🕸️</div>
        <h3 class="text-2xl font-bold mb-2 group-hover:text-nebula-accent">Swarm Forge</h3>
        <p class="text-gray-400">Visual canvas for orchestrating multi-agent swarms</p>
      </a>

      <a href="/memory" class="glass p-8 hover:border-nebula-primary hover:shadow-neon hover:scale-105 transition-all cursor-pointer group">
        <div class="text-4xl mb-4">🧠</div>
        <h3 class="text-2xl font-bold mb-2 group-hover:text-nebula-accent">Memory Vault</h3>
        <p class="text-gray-400">Upload, edit, and inject prompts & knowledge files</p>
      </a>

      <a href="/settings" class="glass p-8 hover:border-nebula-primary hover:shadow-neon hover:scale-105 transition-all cursor-pointer group">
        <div class="text-4xl mb-4">⚙️</div>
        <h3 class="text-2xl font-bold mb-2 group-hover:text-nebula-accent">Settings</h3>
        <p class="text-gray-400">Configure LLM providers and system preferences</p>
      </a>

      <a href="/tools" class="glass p-8 hover:border-nebula-primary hover:shadow-neon hover:scale-105 transition-all cursor-pointer group">
        <div class="text-4xl mb-4">🔧</div>
        <h3 class="text-2xl font-bold mb-2 group-hover:text-nebula-accent">Tool Library</h3>
        <p class="text-gray-400">Manage and approve tool calls (Coming Soon)</p>
      </a>

      <a href="/analytics" class="glass p-8 hover:border-nebula-primary hover:shadow-neon hover:scale-105 transition-all cursor-pointer group">
        <div class="text-4xl mb-4">📊</div>
        <h3 class="text-2xl font-bold mb-2 group-hover:text-nebula-accent">Analytics</h3>
        <p class="text-gray-400">Monitor agent performance and usage (Coming Soon)</p>
      </a>
    </div>

    <!-- Footer Info -->
    <div class="mt-12 text-center text-gray-500 text-sm">
      <p>Powered by NullClaw &bull; Built with SvelteKit & Tailwind</p>
      <p class="mt-1">
        <a href="https://github.com/nullclaw/nullclaw" target="_blank" class="hover:text-nebula-accent">
          GitHub Repository
        </a>
      </p>
    </div>
  </div>
</div>

<style>
  a {
    transition: all 0.3s ease;
  }
</style>
