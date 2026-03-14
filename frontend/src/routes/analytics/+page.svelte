<svelte:options runes={false} />

<script lang="ts">
  import { onMount, onDestroy } from 'svelte';
  import { gatewayConfig } from '$lib/stores/gateway';
  import { GatewayAPI } from '$lib/api/gateway';

  interface AnalyticsStats {
    totalMessages: number;
    userMessages: number;
    assistantMessages: number;
    totalTokens: number;
    topModel: string;
    sessions: number;
    avgTokensPerMessage: number;
  }

  let stats: AnalyticsStats = {
    totalMessages: 0,
    userMessages: 0,
    assistantMessages: 0,
    totalTokens: 0,
    topModel: 'None',
    sessions: 0,
    avgTokensPerMessage: 0
  };

  let gatewayUptime = 0;
  let gatewayVersion = '';
  let refreshInterval: ReturnType<typeof setInterval> | null = null;

  function loadAnalytics() {
    if (typeof localStorage === 'undefined') return;

    // Load stored analytics
    const data = localStorage.getItem('nullclaw_analytics');
    if (data) {
      try {
        const parsed = JSON.parse(data);
        stats = { ...stats, ...parsed };
      } catch {
        // Ignore parse errors
      }
    }

    // Count messages from chat history
    const chatMessages = localStorage.getItem('chat_messages');
    if (chatMessages) {
      try {
        const messages = JSON.parse(chatMessages);
        stats.totalMessages = messages.length;
        stats.userMessages = messages.filter((m: { role: string }) => m.role === 'user').length;
        stats.assistantMessages = messages.filter((m: { role: string }) => m.role === 'assistant').length;
        // Estimate tokens (~4 chars per token)
        stats.totalTokens = messages.reduce((acc: number, m: { content: string }) => {
          return acc + Math.ceil((m.content || '').length / 4);
        }, 0);
        stats.avgTokensPerMessage = stats.totalMessages > 0
          ? Math.round(stats.totalTokens / stats.totalMessages)
          : 0;
      } catch {
        // Ignore parse errors
      }
    }

    // Count sessions
    const sessionId = localStorage.getItem('chat_session_id');
    stats.sessions = sessionId ? 1 : 0;

    // Get current model from gateway config
    const config = localStorage.getItem('gatewayConfig');
    if (config) {
      try {
        const parsed = JSON.parse(config);
        stats.topModel = parsed.model || 'None';
      } catch {
        // Ignore parse errors
      }
    }

    // Persist updated analytics
    localStorage.setItem('nullclaw_analytics', JSON.stringify(stats));
  }

  async function fetchGatewayStats() {
    const api = new GatewayAPI($gatewayConfig.url, $gatewayConfig.bearerToken);
    const status = await api.getStatus();
    if (status) {
      gatewayUptime = status.uptime_seconds;
      gatewayVersion = status.version;
    } else {
      // Clear stale values when gateway is unreachable
      gatewayUptime = 0;
      gatewayVersion = '';
    }
  }

  function formatUptime(seconds: number): string {
    if (seconds === 0) return '--';
    if (seconds < 60) return `${seconds}s`;
    if (seconds < 3600) return `${Math.floor(seconds / 60)}m ${seconds % 60}s`;
    const hours = Math.floor(seconds / 3600);
    const mins = Math.floor((seconds % 3600) / 60);
    return `${hours}h ${mins}m`;
  }

  function formatNumber(n: number): string {
    if (n >= 1000000) return `${(n / 1000000).toFixed(1)}M`;
    if (n >= 1000) return `${(n / 1000).toFixed(1)}K`;
    return String(n);
  }

  function resetAnalytics() {
    if (typeof localStorage === 'undefined') return;
    if (confirm('Reset all analytics data? This cannot be undone.')) {
      localStorage.removeItem('nullclaw_analytics');
      stats = {
        totalMessages: 0,
        userMessages: 0,
        assistantMessages: 0,
        totalTokens: 0,
        topModel: 'None',
        sessions: 0,
        avgTokensPerMessage: 0
      };
      // Don't call loadAnalytics() here — it would re-derive stats from
      // chat_messages and immediately repopulate the values we just zeroed.
    }
  }

  onMount(() => {
    loadAnalytics();
    fetchGatewayStats();
    refreshInterval = setInterval(fetchGatewayStats, 10000);
  });

  onDestroy(() => {
    if (refreshInterval) {
      clearInterval(refreshInterval);
    }
  });
</script>

<div class="min-h-screen p-8">
  <div class="max-w-7xl mx-auto">
    <!-- Header -->
    <header class="mb-8 flex items-center justify-between">
      <div class="flex items-center gap-4">
        <a href="/" class="glass px-4 py-2 rounded-lg hover:bg-nebula-primary/20 transition-all">
          ← Back
        </a>
        <div>
          <h1 class="text-3xl font-bold">System Analytics</h1>
          <p class="text-gray-400 text-sm mt-1">Monitor usage metrics and performance</p>
        </div>
      </div>
      <button
        on:click={resetAnalytics}
        class="glass px-4 py-2 rounded-lg hover:bg-red-500/20 text-sm text-gray-400 hover:text-red-400 transition-all"
      >
        Reset Data
      </button>
    </header>

    <!-- Primary Stats Grid -->
    <div class="grid grid-cols-1 md:grid-cols-4 gap-6 mb-8">
      <div class="glass p-6 hover:scale-105 transition-all">
        <div class="text-nebula-accent text-3xl font-bold font-mono">{formatNumber(stats.totalMessages)}</div>
        <div class="text-sm text-gray-400 mt-1">Total Messages</div>
        <div class="text-xs text-gray-500 mt-2">All chat messages</div>
      </div>

      <div class="glass p-6 hover:scale-105 transition-all">
        <div class="text-nebula-primary text-3xl font-bold font-mono">{formatNumber(stats.totalTokens)}</div>
        <div class="text-sm text-gray-400 mt-1">Est. Tokens Used</div>
        <div class="text-xs text-gray-500 mt-2">~4 chars/token estimate</div>
      </div>

      <div class="glass p-6 hover:scale-105 transition-all">
        <div class="text-nebula-secondary text-3xl font-bold font-mono">{stats.avgTokensPerMessage}</div>
        <div class="text-sm text-gray-400 mt-1">Avg Tokens/Message</div>
        <div class="text-xs text-gray-500 mt-2">Average per message</div>
      </div>

      <div class="glass p-6 hover:scale-105 transition-all">
        <div class="text-green-400 text-3xl font-bold capitalize">{stats.topModel}</div>
        <div class="text-sm text-gray-400 mt-1">Current Model</div>
        <div class="text-xs text-gray-500 mt-2">Active provider model</div>
      </div>
    </div>

    <!-- Gateway Stats -->
    <div class="grid grid-cols-1 md:grid-cols-2 gap-6 mb-8">
      <div class="glass p-6">
        <h2 class="text-xl font-bold mb-4">Gateway Performance</h2>
        <div class="space-y-4">
          <div class="flex items-center justify-between">
            <span class="text-gray-400">Status</span>
            <span class={`font-semibold ${$gatewayConfig.connected ? 'text-green-400' : 'text-red-400'}`}>
              {$gatewayConfig.connected ? 'Online' : 'Offline'}
            </span>
          </div>
          <div class="flex items-center justify-between">
            <span class="text-gray-400">Version</span>
            <span class="font-mono text-nebula-accent">{gatewayVersion || '--'}</span>
          </div>
          <div class="flex items-center justify-between">
            <span class="text-gray-400">Uptime</span>
            <span class="font-mono">{formatUptime(gatewayUptime)}</span>
          </div>
          <div class="flex items-center justify-between">
            <span class="text-gray-400">Gateway URL</span>
            <span class="font-mono text-xs text-gray-500 truncate ml-4">{$gatewayConfig.url}</span>
          </div>
          <div class="flex items-center justify-between">
            <span class="text-gray-400">Provider</span>
            <span class="font-semibold capitalize">{$gatewayConfig.provider}</span>
          </div>
        </div>
      </div>

      <div class="glass p-6">
        <h2 class="text-xl font-bold mb-4">Usage Breakdown</h2>
        <div class="space-y-4">
          <div class="flex items-center justify-between">
            <span class="text-gray-400">Chat Sessions</span>
            <span class="font-mono text-nebula-accent">{stats.sessions}</span>
          </div>
          <div class="flex items-center justify-between">
            <span class="text-gray-400">User Messages</span>
            <span class="font-mono">{stats.userMessages}</span>
          </div>
          <div class="flex items-center justify-between">
            <span class="text-gray-400">Assistant Replies</span>
            <span class="font-mono">{stats.assistantMessages}</span>
          </div>
          <div class="flex items-center justify-between">
            <span class="text-gray-400">Data Source</span>
            <span class="text-xs text-gray-500">localStorage (local only)</span>
          </div>
          <div class="flex items-center justify-between">
            <span class="text-gray-400">Paired</span>
            <span class={`font-semibold ${$gatewayConfig.paired ? 'text-green-400' : 'text-yellow-400'}`}>
              {$gatewayConfig.paired ? 'Yes' : 'No'}
            </span>
          </div>
        </div>
      </div>
    </div>

    <!-- Info Banner -->
    <div class="glass p-4 text-center text-sm text-gray-500">
      Analytics data is stored locally in your browser. Token estimates are approximate (~4 characters per token).
      <br />
      Future versions will include server-side analytics, cost tracking, and latency monitoring.
    </div>
  </div>
</div>
