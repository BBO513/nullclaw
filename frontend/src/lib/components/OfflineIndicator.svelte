<svelte:options runes={false} />

<script lang="ts">
  import { onMount } from 'svelte';
  import { gatewayConfig, checkGatewayHealth } from '$lib/stores/gateway';

  let isOnline = true;
  let gatewayOnline = false;
  let checking = false;
  let dismissed = false;
  let dismissTimeout: ReturnType<typeof setTimeout> | null = null;
  let statusText = '';
  let statusColor = '';

  async function checkGateway() {
    if (!isOnline) {
      gatewayOnline = false;
      updateStatus();
      return;
    }

    checking = true;
    updateStatus();

    gatewayOnline = await checkGatewayHealth($gatewayConfig.url);
    checking = false;
    updateStatus();

    gatewayConfig.update(c => ({ ...c, connected: gatewayOnline }));
  }

  function updateStatus() {
    if (!isOnline) {
      statusText = 'No Internet';
      statusColor = 'bg-red-500';
    } else if (checking) {
      statusText = 'Checking...';
      statusColor = 'bg-yellow-500';
    } else if (!gatewayOnline) {
      statusText = 'Gateway Offline';
      statusColor = 'bg-red-500';
    } else {
      statusText = 'Connected';
      statusColor = 'bg-green-500';
    }
  }

  function dismiss() {
    dismissed = true;
    // Re-show after 60 seconds if still offline
    if (dismissTimeout) clearTimeout(dismissTimeout);
    dismissTimeout = setTimeout(() => { dismissed = false; }, 60000);
  }

  onMount(() => {
    isOnline = navigator.onLine;
    updateStatus();

    // Check gateway on mount
    checkGateway();

    // Check gateway every 15 seconds
    const interval = setInterval(checkGateway, 15000);

    // Listen for online/offline events
    const handleOnline = () => {
      isOnline = true;
      dismissed = false;
      checkGateway();
    };

    const handleOffline = () => {
      isOnline = false;
      gatewayOnline = false;
      dismissed = false;
      updateStatus();
      gatewayConfig.update(c => ({ ...c, connected: false }));
    };

    window.addEventListener('online', handleOnline);
    window.addEventListener('offline', handleOffline);

    return () => {
      clearInterval(interval);
      if (dismissTimeout) clearTimeout(dismissTimeout);
      window.removeEventListener('online', handleOnline);
      window.removeEventListener('offline', handleOffline);
    };
  });
</script>

{#if (!isOnline || !gatewayOnline) && !dismissed}
  <div class="fixed top-0 left-0 right-0 z-50 animate-slide-down">
    <div class={`px-4 py-3 ${!isOnline ? 'bg-red-900/90 border-b border-red-500/40' : 'bg-yellow-900/90 border-b border-yellow-500/40'}`}>
      <div class="max-w-7xl mx-auto flex items-center justify-between">
        <div class="flex items-center gap-3">
          <div class={`w-2.5 h-2.5 rounded-full ${statusColor} animate-pulse`}></div>
          <div>
            <span class={`text-sm font-semibold ${!isOnline ? 'text-red-400' : 'text-yellow-400'}`}>
              {statusText}
            </span>
            {#if !isOnline}
              <span class="text-xs text-red-300/70 ml-2">Check your internet connection</span>
            {:else}
              <span class="text-xs text-yellow-300/70 ml-2">
                NullClaw gateway at {$gatewayConfig.url} is not responding.
                Run <code class="bg-black/30 px-1 rounded">nullclaw serve</code> to start it.
              </span>
            {/if}
          </div>
        </div>
        <div class="flex items-center gap-3">
          {#if isOnline && !gatewayOnline}
            <button
              on:click={checkGateway}
              disabled={checking}
              class="text-xs px-3 py-1 rounded bg-yellow-500/20 border border-yellow-500/30 text-yellow-300 hover:bg-yellow-500/30 disabled:opacity-50 transition-all"
            >
              {checking ? 'Checking...' : 'Retry'}
            </button>
          {/if}
          <button
            on:click={dismiss}
            class="text-xs text-gray-400 hover:text-white ml-1"
            title="Dismiss for 60 seconds"
          >
            ✕
          </button>
        </div>
      </div>
    </div>
  </div>
{/if}

<style>
  @keyframes slide-down {
    from {
      transform: translateY(-100%);
      opacity: 0;
    }
    to {
      transform: translateY(0);
      opacity: 1;
    }
  }

  .animate-slide-down {
    animation: slide-down 0.3s ease-out;
  }
</style>
