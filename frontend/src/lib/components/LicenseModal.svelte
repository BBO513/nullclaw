<svelte:options runes={false} />

<script lang="ts">
  import { license, activateLicense } from '$lib/stores/license';

  export let show = false;
  export let onClose: () => void = () => {};
  
  let licenseKey = '';
  let error = '';
  let activating = false;

  function handleActivate() {
    if (!licenseKey.trim()) {
      error = 'Please enter a license key';
      return;
    }

    activating = true;
    error = '';

    // Simulate activation delay
    setTimeout(() => {
      const success = activateLicense(licenseKey.trim().toUpperCase());
      
      if (success) {
        licenseKey = '';
        alert('✅ License activated successfully! Pro features unlocked.');
        show = false;
      } else {
        error = 'Invalid license key format. Expected: NULLCLAW-XXXX-XXXX-XXXX';
      }
      
      activating = false;
    }, 500);
  }

  function handleClose() {
    show = false;
    licenseKey = '';
    error = '';
  }
</script>

{#if show}
  <div class="fixed inset-0 bg-black/80 flex items-center justify-center p-8 z-50">
    <div class="glass max-w-2xl w-full p-8">
      <h2 class="text-2xl font-bold mb-4">Activate License</h2>
      
      <p class="text-gray-400 mb-6">
        Enter your NullClaw Nexus Pro license key to unlock unlimited features.
      </p>

      <div class="mb-6">
        <label for="license-key" class="block text-sm text-gray-400 mb-2">License Key</label>
        <input
          id="license-key"
          type="text"
          bind:value={licenseKey}
          placeholder="NULLCLAW-XXXX-XXXX-XXXX"
          disabled={activating}
          class="w-full glass px-4 py-3 rounded-lg font-mono focus:outline-none focus:ring-2 focus:ring-nebula-primary"
        />
        <p class="text-xs text-gray-500 mt-2">
          Master keys: NULLCLAW-CREATOR-UNLIMITED, NULLCLAW-DEV-MASTER-2026, NULLCLAW-ADMIN-FULL-ACCESS
        </p>
      </div>

      {#if error}
        <div class="mb-4 p-3 bg-red-500/10 border border-red-500/30 rounded-lg">
          <p class="text-sm text-red-500">{error}</p>
        </div>
      {/if}

      <!-- Free vs Pro Comparison -->
      <div class="grid grid-cols-2 gap-4 mb-6">
        <div class="glass p-4 rounded-lg">
          <h3 class="font-bold mb-3 text-gray-400">Free Tier</h3>
          <ul class="text-sm space-y-2">
            <li class="flex items-center gap-2">
              <span class="text-yellow-500">⚠️</span>
              <span>3 agents max</span>
            </li>
            <li class="flex items-center gap-2">
              <span class="text-yellow-500">⚠️</span>
              <span>5 memories max</span>
            </li>
            <li class="flex items-center gap-2">
              <span class="text-green-500">✓</span>
              <span>All core features</span>
            </li>
          </ul>
        </div>
        <div class="bg-gradient-to-br from-nebula-primary/20 to-nebula-accent/20 p-4 rounded-lg border-2 border-nebula-primary/30">
          <h3 class="font-bold mb-3 text-nebula-primary">Pro ($9.99)</h3>
          <ul class="text-sm space-y-2">
            <li class="flex items-center gap-2">
              <span class="text-green-500">✓</span>
              <span>Unlimited agents</span>
            </li>
            <li class="flex items-center gap-2">
              <span class="text-green-500">✓</span>
              <span>Unlimited memories</span>
            </li>
            <li class="flex items-center gap-2">
              <span class="text-green-500">✓</span>
              <span>Priority support</span>
            </li>
          </ul>
        </div>
      </div>

      <p class="text-xs text-center text-gray-500 mb-6">
        Purchase at <a href="https://gumroad.com/nullclaw" target="_blank" class="text-nebula-accent hover:underline">gumroad.com/nullclaw</a>
      </p>

      <div class="flex gap-4">
        <button
          on:click={handleClose}
          disabled={activating}
          class="flex-1 px-6 py-3 glass hover:bg-nebula-card disabled:opacity-50 rounded-lg font-semibold"
        >
          Skip for Now
        </button>
        <button
          on:click={handleActivate}
          disabled={activating || !licenseKey.trim()}
          class="flex-1 px-6 py-3 bg-gradient-to-r from-nebula-primary to-nebula-accent hover:opacity-90 disabled:opacity-50 rounded-lg font-semibold"
        >
          {activating ? 'Activating...' : 'Activate License'}
        </button>
      </div>
    </div>
  </div>
{/if}
