<script lang="ts">
  import { onMount, onDestroy } from 'svelte';
  import { gatewayConfig } from '$lib/stores/gateway';
  import { GatewayAPI } from '$lib/api/gateway';

  let queueData: {
    mode: string;
    pending: number;
    processed: number;
    dropped: number;
    sessions: number;
    rate_limits: {
      pair: number;
      webhook: number;
    };
  } | null = null;
  
  let loading = true;
  let error: string | null = null;
  let refreshInterval: number | null = null;

  async function fetchQueueStatus() {
    if (!$gatewayConfig.connected || !$gatewayConfig.url) {
      error = 'Gateway not connected';
      loading = false;
      return;
    }

    try {
      const api = new GatewayAPI($gatewayConfig.url, $gatewayConfig.bearerToken);
      const response = await fetch(`${$gatewayConfig.url}/status`, {
        headers: {
          'Authorization': `Bearer ${$gatewayConfig.bearerToken}`
        }
      });
      
      if (!response.ok) {
        throw new Error(`Failed to fetch queue status: ${response.status} ${response.statusText}`);
      }
      
      const data = await response.json();
      queueData = data;
      error = null;
    } catch (err) {
      error = err instanceof Error ? err.message : String(err);
      queueData = null;
    } finally {
      loading = false;
    }
  }

  function startPolling() {
    if (refreshInterval) {
      clearInterval(refreshInterval);
    }
    refreshInterval = window.setInterval(fetchQueueStatus, 5000); // Poll every 5 seconds
  }

  function stopPolling() {
    if (refreshInterval) {
      clearInterval(refreshInterval);
      refreshInterval = null;
    }
  }

  onMount(async () => {
    await fetchQueueStatus();
    startPolling();
  });

  onDestroy(() => {
    stopPolling();
  });

  function getQueueModeColor(mode: string) {
    switch (mode) {
      case 'off': return 'bg-gray-500';
      case 'serial': return 'bg-blue-500';
      case 'latest': return 'bg-green-500';
      case 'debounce': return 'bg-yellow-500';
      default: return 'bg-gray-500';
    }
  }

  function getQueueModeLabel(mode: string) {
    switch (mode) {
      case 'off': return 'Queue Off';
      case 'serial': return 'Serial Processing';
      case 'latest': return 'Latest Only';
      case 'debounce': return 'Debounce Mode';
      default: return mode;
    }
  }
</script>

<div class="glass p-6">
  <div class="flex items-center justify-between mb-4">
    <h3 class="text-xl font-bold">Lane Queue Monitoring</h3>
    <div class="flex items-center gap-2">
      <div class={`w-3 h-3 rounded-full ${loading ? 'bg-yellow-500 animate-pulse' : error ? 'bg-red-500' : 'bg-green-500'}`}></div>
      <span class="text-sm">{loading ? 'Loading...' : error ? 'Error' : 'Live'}</span>
    </div>
  </div>

  {#if loading}
    <div class="text-center py-8">
      <div class="animate-spin text-2xl mb-2">⏳</div>
      <p class="text-gray-400">Loading queue status...</p>
    </div>
  {:else if error}
    <div class="text-center py-8">
      <div class="text-2xl mb-2 text-red-400">⚠️</div>
      <p class="text-red-400 mb-2">Failed to load queue status</p>
      <p class="text-sm text-gray-400">{error}</p>
      <button 
        on:click={fetchQueueStatus}
        class="mt-4 px-4 py-2 glass hover:bg-nebula-card rounded-lg text-sm"
      >
        Retry
      </button>
    </div>
  {:else if queueData}
    <div class="space-y-6">
      <!-- Queue Mode Card -->
      <div class="border border-nebula-primary/20 rounded-lg p-4">
        <div class="flex items-center justify-between mb-2">
          <span class="text-sm text-gray-400">Queue Mode</span>
          <div class="flex items-center gap-2">
            <div class={`w-3 h-3 rounded-full ${getQueueModeColor(queueData.mode)}`}></div>
            <span class="font-medium">{getQueueModeLabel(queueData.mode)}</span>
          </div>
        </div>
        <div class="text-xs text-gray-500">
          {#if queueData.mode === 'off'}
            Messages are processed immediately without queuing
          {:else if queueData.mode === 'serial'}
            Messages are processed one at a time in order
          {:else if queueData.mode === 'latest'}
            Only the latest message is kept, older ones are dropped
          {:else if queueData.mode === 'debounce'}
            Messages are debounced before processing
          {/if}
        </div>
      </div>

      <!-- Queue Stats -->
      <div class="grid grid-cols-3 gap-4">
        <div class="text-center">
          <div class="text-3xl font-bold text-nebula-primary">{queueData.pending}</div>
          <div class="text-xs text-gray-400 mt-1">Pending</div>
        </div>
        <div class="text-center">
          <div class="text-3xl font-bold text-green-500">{queueData.processed}</div>
          <div class="text-xs text-gray-400 mt-1">Processed</div>
        </div>
        <div class="text-center">
          <div class="text-3xl font-bold text-red-500">{queueData.dropped}</div>
          <div class="text-xs text-gray-400 mt-1">Dropped</div>
        </div>
      </div>

      <!-- Session Info -->
      <div class="border border-nebula-primary/20 rounded-lg p-4">
        <div class="flex items-center justify-between">
          <span class="text-sm text-gray-400">Active Sessions</span>
          <span class="font-bold text-nebula-accent">{queueData.sessions}</span>
        </div>
      </div>

      <!-- Rate Limits -->
      <div class="border border-nebula-primary/20 rounded-lg p-4">
        <h4 class="text-sm font-medium mb-3">Rate Limits (per minute)</h4>
        <div class="space-y-2">
          <div class="flex items-center justify-between">
            <span class="text-xs text-gray-400">Pair Requests</span>
            <span class="text-sm font-medium">{queueData.rate_limits.pair}</span>
          </div>
          <div class="flex items-center justify-between">
            <span class="text-xs text-gray-400">Webhook Requests</span>
            <span class="text-sm font-medium">{queueData.rate_limits.webhook}</span>
          </div>
        </div>
      </div>

      <!-- Actions -->
      <div class="flex gap-2">
        <button 
          on:click={fetchQueueStatus}
          class="flex-1 px-4 py-2 glass hover:bg-nebula-card rounded-lg text-sm"
        >
          Refresh
        </button>
        <button 
          on:click={() => refreshInterval ? stopPolling() : startPolling()}
          class="flex-1 px-4 py-2 glass hover:bg-nebula-card rounded-lg text-sm"
        >
          {refreshInterval ? 'Pause Auto-Refresh' : 'Resume Auto-Refresh'}
        </button>
      </div>
    </div>
  {:else}
    <div class="text-center py-8">
      <div class="text-2xl mb-2">📊</div>
      <p class="text-gray-400">No queue data available</p>
    </div>
  {/if}
</div>