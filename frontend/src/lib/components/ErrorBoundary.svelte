<script lang="ts">
  import { onMount } from 'svelte';

  let hasError = false;
  let errorMessage = '';
  let errorStack = '';

  onMount(() => {
    // Global error handler
    const handleError = (event: ErrorEvent) => {
      console.error('Global error:', event.error);
      hasError = true;
      errorMessage = event.error?.message || 'An unexpected error occurred';
      errorStack = event.error?.stack || '';
      event.preventDefault();
    };

    // Unhandled promise rejection handler
    const handleRejection = (event: PromiseRejectionEvent) => {
      console.error('Unhandled rejection:', event.reason);
      hasError = true;
      errorMessage = event.reason?.message || 'An unexpected error occurred';
      errorStack = event.reason?.stack || '';
      event.preventDefault();
    };

    window.addEventListener('error', handleError);
    window.addEventListener('unhandledrejection', handleRejection);

    return () => {
      window.removeEventListener('error', handleError);
      window.removeEventListener('unhandledrejection', handleRejection);
    };
  });

  function reload() {
    window.location.reload();
  }

  function goHome() {
    window.location.href = '/';
  }
</script>

{#if hasError}
  <div class="min-h-screen flex items-center justify-center p-8 bg-nebula-bg">
    <div class="glass max-w-2xl w-full p-8 border-2 border-red-500/30">
      <div class="text-center mb-6">
        <div class="text-6xl mb-4">⚠️</div>
        <h1 class="text-3xl font-bold text-red-500 mb-2">Something Went Wrong</h1>
        <p class="text-gray-400">
          The application encountered an unexpected error. This has been logged for investigation.
        </p>
      </div>

      <div class="bg-nebula-bg/50 border border-red-500/20 rounded-lg p-4 mb-6">
        <p class="text-sm font-mono text-red-400 mb-2">{errorMessage}</p>
        {#if errorStack}
          <details class="text-xs text-gray-500">
            <summary class="cursor-pointer hover:text-gray-400">Show technical details</summary>
            <pre class="mt-2 overflow-x-auto">{errorStack}</pre>
          </details>
        {/if}
      </div>

      <div class="flex gap-4">
        <button
          on:click={goHome}
          class="flex-1 px-6 py-3 glass hover:bg-nebula-card rounded-lg font-semibold"
        >
          Go to Dashboard
        </button>
        <button
          on:click={reload}
          class="flex-1 px-6 py-3 bg-nebula-primary hover:bg-nebula-primaryLight rounded-lg font-semibold"
        >
          Reload Page
        </button>
      </div>

      <div class="mt-6 text-center text-sm text-gray-500">
        <p>If this problem persists, please:</p>
        <ul class="mt-2 space-y-1">
          <li>• Check that NullClaw gateway is running</li>
          <li>• Clear browser cache and reload</li>
          <li>• Check browser console for errors</li>
          <li>• Report issue on GitHub</li>
        </ul>
      </div>
    </div>
  </div>
{:else}
  <slot />
{/if}

<style>
  details summary {
    list-style: none;
  }
  
  details summary::-webkit-details-marker {
    display: none;
  }
</style>
