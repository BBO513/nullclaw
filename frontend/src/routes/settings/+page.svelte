<svelte:options runes={false} />

<script lang="ts">
  import { onMount, onDestroy } from 'svelte';
  import { gatewayConfig, providers, ollamaModels, openaiModels, claudeModels } from '$lib/stores/gateway';
  import { currentTheme, proUnlocked } from '$lib/stores/theme';
  import { license, deactivateLicense } from '$lib/stores/license';
  import { GatewayAPI } from '$lib/api/gateway';
  import PairingModal from '$lib/components/PairingModal.svelte';
  import LicenseModal from '$lib/components/LicenseModal.svelte';
  import SetupWizard from '$lib/components/SetupWizard.svelte';

  let mounted = false;
  let gatewayUrl = '';
  let selectedProvider = '';
  let selectedModel = '';
  let ollamaDetected = false;
  let checking = false;
  let availableOllamaModels: string[] = [];
  let showPairing = false;
  let showLicenseModal = false;
  let showSetupWizard = false;
  let isRemoteGateway = false;
  let modelList: string[] = [];
  let apiKey = '';
  let customBaseUrl = '';
  let syncing = false;
  let syncStatus: 'idle' | 'success' | 'error' = 'idle';
  let syncMessage = '';
  let syncTimeout: ReturnType<typeof setTimeout> | null = null;
  let syncingFromGateway = false;

  onMount(async () => {
    mounted = true;
    gatewayUrl = $gatewayConfig.url;
    selectedProvider = $gatewayConfig.provider;
    selectedModel = $gatewayConfig.model;
    
    // Load API key from localStorage
    if (typeof localStorage !== 'undefined') {
      apiKey = localStorage.getItem(`apiKey_${selectedProvider}`) || '';
      customBaseUrl = localStorage.getItem('customBaseUrl') || '';
    }
    
    updateModelList();
    await checkOllama();

    // Fetch current provider config from gateway to sync state
    try {
      const api = new GatewayAPI($gatewayConfig.url, $gatewayConfig.bearerToken);
      const providerConfig = await api.getProviderConfig();
      if (providerConfig) {
        console.log('[Settings] Loaded provider config from gateway:', providerConfig);
        syncingFromGateway = true;
        // Update local state to match gateway
        if (providerConfig.type && providerConfig.type !== selectedProvider) {
          selectedProvider = providerConfig.type;
          gatewayConfig.update(c => ({ ...c, provider: providerConfig.type }));
        }
        if (providerConfig.model && providerConfig.model !== selectedModel) {
          selectedModel = providerConfig.model;
          gatewayConfig.update(c => ({ ...c, model: providerConfig.model }));
        }
        updateModelList();
        syncingFromGateway = false;
      }
    } catch (err) {
      console.warn('[Settings] Could not fetch provider config from gateway:', err);
      syncingFromGateway = false;
    }
  });

  function updateModelList() {
    isRemoteGateway = !gatewayUrl.includes('127.0.0.1') && !gatewayUrl.includes('localhost');
    
    switch (selectedProvider) {
      case 'ollama':
        // Use detected models from local Ollama, fallback to common models if none detected
        modelList = availableOllamaModels.length > 0 ? availableOllamaModels : ollamaModels;
        break;
      case 'openai':
        modelList = openaiModels;
        break;
      case 'anthropic':
        modelList = claudeModels;
        break;
      default:
        modelList = [];
    }
    // Handle models not in the hardcoded list
    if (selectedModel && modelList.length > 0 && !modelList.includes(selectedModel)) {
      if (syncingFromGateway) {
        // Preserve gateway-synced models (e.g. fine-tuned or versioned models)
        modelList = [selectedModel, ...modelList];
      } else {
        // User switched providers — reset to first available model
        selectedModel = modelList[0];
      }
    }
    // Auto-select first model only if no model is selected
    if (modelList.length > 0 && !selectedModel) {
      selectedModel = modelList[0];
    }
  }

  $: {
    selectedProvider;
    updateModelList();
    // Load API key when provider changes
    if (typeof localStorage !== 'undefined') {
      apiKey = localStorage.getItem(`apiKey_${selectedProvider}`) || '';
    }
  }

  async function testConnection() {
    checking = true;
    const api = new GatewayAPI(gatewayUrl, $gatewayConfig.bearerToken);
    const connected = await api.checkHealth();
    
    if (connected) {
      gatewayConfig.update(c => ({ ...c, url: gatewayUrl, connected: true }));
      alert('✅ Connection successful!');
    } else {
      alert('❌ Could not connect to gateway');
    }
    checking = false;
  }

  /** Resolve the provider's upstream base URL for the gateway */
  function getProviderBaseUrl(provider: string): string {
    if (provider === 'custom' || provider === 'azure') {
      return customBaseUrl || '';
    }
    const urls: Record<string, string> = {
      ollama: 'http://localhost:11434',
      openai: 'https://api.openai.com/v1',
      anthropic: 'https://api.anthropic.com/v1',
      groq: 'https://api.groq.com/openai/v1',
      together: 'https://api.together.xyz/v1',
      openrouter: 'https://openrouter.ai/api/v1',
      cohere: 'https://api.cohere.ai/v1',
      mistral: 'https://api.mistral.ai/v1',
      perplexity: 'https://api.perplexity.ai',
      deepseek: 'https://api.deepseek.com/v1',
      google: 'https://generativelanguage.googleapis.com/v1',
      huggingface: 'https://api-inference.huggingface.co/models',
      replicate: 'https://api.replicate.com/v1',
      anyscale: 'https://api.endpoints.anyscale.com/v1',
      fireworks: 'https://api.fireworks.ai/inference/v1',
      deepinfra: 'https://api.deepinfra.com/v1/openai',
      lepton: 'https://api.lepton.ai/api/v1',
      octoai: 'https://text.octoai.run/v1',
      novita: 'https://api.novita.ai/v3/openai',
      cerebras: 'https://api.cerebras.ai/v1',
      sambanova: 'https://api.sambanova.ai/v1',
    };
    return urls[provider] || '';
  }

  async function saveSettings() {
    // Update local store
    gatewayConfig.update(c => ({ 
      ...c, 
      url: gatewayUrl,
      provider: selectedProvider,
      model: selectedModel 
    }));
    
    // Save API key to localStorage
    if (typeof localStorage !== 'undefined') {
      if (apiKey) {
        localStorage.setItem(`apiKey_${selectedProvider}`, apiKey);
      }
      if (customBaseUrl) {
        localStorage.setItem('customBaseUrl', customBaseUrl);
      }
    }

    // Sync to gateway via POST /config/provider
    syncing = true;
    syncStatus = 'idle';
    try {
      const api = new GatewayAPI(gatewayUrl, $gatewayConfig.bearerToken);
      const providerPayload: Record<string, string> = {
        type: selectedProvider,
        base_url: getProviderBaseUrl(selectedProvider),
        model: selectedModel,
      };
      if (apiKey) {
        providerPayload.api_key = apiKey;
      }
      const result = await api.updateProvider(providerPayload as { type: string; base_url: string; model: string; api_key?: string });
      if (result.success) {
        syncStatus = 'success';
        syncMessage = 'Settings saved & synced to gateway';
      } else {
        syncStatus = 'error';
        syncMessage = `Saved locally. Gateway sync failed: ${result.message}`;
      }
    } catch {
      syncStatus = 'error';
      syncMessage = 'Saved locally. Could not reach gateway to sync.';
    }
    syncing = false;

    // Clear sync status after 4 seconds
    if (syncTimeout) clearTimeout(syncTimeout);
    syncTimeout = setTimeout(() => { syncStatus = 'idle'; }, 4000);
  }

  async function checkOllama() {
    try {
      const api = new GatewayAPI();
      const models = await api.getOllamaModels();
      availableOllamaModels = models;
      ollamaDetected = models.length > 0;
      
      if (ollamaDetected) {
        console.log(`✅ Ollama detected with ${models.length} models:`, models);
      } else {
        console.log('⚠️ Ollama not detected or no models installed');
      }
      
      updateModelList();
    } catch (error) {
      console.error('Failed to check Ollama:', error);
      ollamaDetected = false;
    }
  }

  onDestroy(() => {
    if (syncTimeout) clearTimeout(syncTimeout);
  });

  function unlockPro() {
    showLicenseModal = true;
  }

  function deactivateLicenseKey() {
    if (confirm('Are you sure you want to deactivate your license? Pro features will be locked.')) {
      deactivateLicense();
      alert('✅ License deactivated successfully');
    }
  }

  function repairGateway() {
    showPairing = true;
  }

  function unpairGateway() {
    if (confirm('Are you sure you want to unpair from the gateway? You will need to pair again to use AI features.')) {
      gatewayConfig.update(c => ({
        ...c,
        bearerToken: null,
        paired: false,
        connected: false
      }));
      alert('✅ Gateway unpaired successfully');
    }
  }

  function runSetupWizard() {
    showSetupWizard = true;
  }
</script>

<SetupWizard bind:show={showSetupWizard} />
<PairingModal bind:show={showPairing} />
<LicenseModal bind:show={showLicenseModal} />

{#if !mounted}
  <div class="min-h-screen flex items-center justify-center">
    <div class="text-center">
      <div class="text-4xl mb-4">⏳</div>
      <p class="text-gray-400">Loading...</p>
    </div>
  </div>
{:else}
  <div class="min-h-screen p-8">
    <div class="max-w-4xl mx-auto">
      <!-- Header -->
      <header class="mb-8">
        <a href="/" class="glass px-4 py-2 rounded-lg hover:bg-nebula-primary/20 transition-all inline-flex items-center gap-2 mb-4">
          <span class="text-xl">←</span>
          <span>Back</span>
        </a>
        <h1 class="text-4xl font-bold mt-4">Settings</h1>
        <p class="text-gray-400 mt-2">Configure your NullClaw Nexus experience</p>
      </header>

      <!-- Security Warning for Remote Gateway -->
      {#if isRemoteGateway}
        <div class="bg-red-500/10 border border-red-500/30 rounded-lg p-4 mb-6">
          <p class="text-red-500 font-semibold">⚠️ Security Warning</p>
          <p class="text-sm text-gray-400 mt-1">
            You are connecting to a remote gateway. Ensure the connection is secure (HTTPS) and the gateway is trusted.
            For maximum security, use localhost (127.0.0.1) only.
          </p>
        </div>
      {/if}

      <!-- Gateway Pairing Status -->
      <section class="glass p-6 mb-6">
        <h2 class="text-2xl font-bold mb-4">Gateway Authentication</h2>
        <div class="flex items-center justify-between">
          <div>
            <p class="font-semibold">
              {$gatewayConfig.paired ? '✅ Paired' : '❌ Not Paired'}
            </p>
            <p class="text-sm text-gray-400 mt-1">
              {$gatewayConfig.paired 
                ? 'Secure connection established with bearer token' 
                : 'Pair with gateway to enable AI features'}
            </p>
          </div>
          <div class="flex gap-2">
            {#if $gatewayConfig.paired}
              <button
                on:click={unpairGateway}
                class="px-4 py-2 glass hover:bg-red-500/20 rounded-lg text-sm"
              >
                Unpair
              </button>
            {/if}
            <button
              on:click={repairGateway}
              class="px-4 py-2 bg-nebula-primary hover:bg-nebula-primaryLight rounded-lg font-semibold text-sm"
            >
              {$gatewayConfig.paired ? 'Re-pair' : 'Pair Now'}
            </button>
          </div>
        </div>
      </section>

      <!-- Gateway Connection -->
      <section class="glass p-6 mb-6">
        <h2 class="text-2xl font-bold mb-4">Gateway Connection</h2>
        <div class="space-y-4">
          <div>
            <label for="gateway-url" class="block text-sm text-gray-400 mb-2">Gateway URL</label>
            <div class="flex gap-2">
              <input
                id="gateway-url"
                type="text"
                bind:value={gatewayUrl}
                placeholder="http://127.0.0.1:3000"
                class="flex-1 glass px-4 py-2 rounded-lg focus:outline-none focus:ring-2 focus:ring-nebula-primary"
              />
              <button
                on:click={testConnection}
                disabled={checking}
                class="px-6 py-2 bg-nebula-primary hover:bg-nebula-primaryLight disabled:opacity-50 rounded-lg font-semibold"
              >
                {checking ? 'Testing...' : 'Test'}
              </button>
            </div>
          </div>
          <div class="flex items-center gap-2 text-sm">
            <div class={`w-2 h-2 rounded-full ${$gatewayConfig.connected ? 'bg-green-500' : 'bg-red-500'}`}></div>
            <span>{$gatewayConfig.connected ? 'Connected' : 'Disconnected'}</span>
          </div>
        </div>
      </section>

      <!-- LLM Provider -->
      <section class="glass p-6 mb-6">
        <div class="flex items-center justify-between mb-4">
          <h2 class="text-2xl font-bold">LLM Provider</h2>
          {#if selectedProvider === 'ollama'}
            <button
              on:click={checkOllama}
              class="px-3 py-1 text-sm glass hover:bg-nebula-card rounded-lg"
            >
              🔄 Refresh Models
            </button>
          {/if}
        </div>
        
        {#if selectedProvider === 'ollama' && !ollamaDetected}
          <div class="bg-yellow-500/10 border border-yellow-500/30 rounded-lg p-4 mb-4">
            <p class="text-yellow-500 font-semibold">⚠️ Ollama not detected</p>
            <p class="text-sm text-gray-400 mt-1">
              Run <code class="bg-nebula-bg px-2 py-1 rounded">ollama serve</code> and pull a model to use local LLMs
            </p>
            <p class="text-xs text-gray-500 mt-2">
              Example: <code class="bg-nebula-bg px-2 py-1 rounded">ollama pull llama3.1</code>
            </p>
          </div>
        {:else if selectedProvider === 'ollama' && ollamaDetected}
          <div class="bg-green-500/10 border border-green-500/30 rounded-lg p-4 mb-4">
            <p class="text-green-500 font-semibold">✅ Ollama detected</p>
            <p class="text-sm text-gray-400 mt-1">
              Found {availableOllamaModels.length} installed model{availableOllamaModels.length !== 1 ? 's' : ''}: {availableOllamaModels.join(', ')}
            </p>
          </div>
        {/if}

        <div class="space-y-4">
          <div>
            <label for="provider-select" class="block text-sm text-gray-400 mb-2">Select Provider</label>
            <select
              id="provider-select"
              bind:value={selectedProvider}
              class="w-full glass px-4 py-2 rounded-lg focus:outline-none focus:ring-2 focus:ring-nebula-primary"
            >
              {#each providers as provider}
                <option value={provider.id}>
                  {provider.name} {provider.priority ? '⭐' : ''}
                </option>
              {/each}
            </select>
          </div>

          <div>
            <label for="model-select" class="block text-sm text-gray-400 mb-2">
              Select Model
              {#if selectedProvider === 'ollama' && availableOllamaModels.length > 0}
                <span class="text-green-500 text-xs ml-2">({availableOllamaModels.length} detected locally)</span>
              {/if}
            </label>
            <select
              id="model-select"
              bind:value={selectedModel}
              class="w-full glass px-4 py-2 rounded-lg focus:outline-none focus:ring-2 focus:ring-nebula-primary"
            >
              {#each modelList as model}
                <option value={model}>{model}</option>
              {/each}
            </select>
            {#if selectedProvider === 'ollama' && availableOllamaModels.length === 0}
              <p class="text-xs text-gray-500 mt-2">
                No models detected. Pull a model: <code class="bg-nebula-bg px-2 py-1 rounded">ollama pull llama3.1</code>
              </p>
            {/if}
          </div>

          {#if selectedProvider !== 'ollama'}
            <div>
              <label for="api-key" class="block text-sm text-gray-400 mb-2">
                API Key {selectedProvider === 'custom' ? '(Optional)' : '(Required)'}
              </label>
              <input
                id="api-key"
                type="password"
                bind:value={apiKey}
                placeholder="Enter your API key"
                class="w-full glass px-4 py-2 rounded-lg focus:outline-none focus:ring-2 focus:ring-nebula-primary"
              />
              <p class="text-xs text-gray-500 mt-1">
                Your API key is stored locally and sent to your gateway on sync
              </p>
            </div>
          {/if}

          {#if selectedProvider === 'custom' || selectedProvider === 'azure'}
            <div>
              <label for="custom-url" class="block text-sm text-gray-400 mb-2">
                Custom Base URL
              </label>
              <input
                id="custom-url"
                type="text"
                bind:value={customBaseUrl}
                placeholder="https://api.example.com/v1"
                class="w-full glass px-4 py-2 rounded-lg focus:outline-none focus:ring-2 focus:ring-nebula-primary"
              />
            </div>
          {/if}
        </div>
      </section>

      <!-- Theme -->
      <section class="glass p-6 mb-6">
        <h2 class="text-2xl font-bold mb-4">Theme</h2>
        <div class="grid grid-cols-3 gap-4">
          <button
            on:click={() => currentTheme.set('nebula')}
            class={`p-4 rounded-lg border-2 ${$currentTheme === 'nebula' ? 'border-nebula-primary' : 'border-transparent'} bg-gradient-to-br from-nebula-primary to-nebula-accent`}
          >
            <div class="text-white font-bold">Nebula</div>
          </button>
          <button
            on:click={() => currentTheme.set('void')}
            class={`p-4 rounded-lg border-2 ${$currentTheme === 'void' ? 'border-nebula-primary' : 'border-transparent'} bg-gradient-to-br from-gray-900 to-black`}
          >
            <div class="text-white font-bold">Void</div>
          </button>
          <button
            on:click={() => currentTheme.set('eclipse')}
            class={`p-4 rounded-lg border-2 ${$currentTheme === 'eclipse' ? 'border-nebula-primary' : 'border-transparent'} bg-gradient-to-br from-orange-600 to-red-900`}
          >
            <div class="text-white font-bold">Eclipse</div>
          </button>
        </div>
      </section>

      <!-- License Status -->
      <section class="glass p-6 mb-6">
        <h2 class="text-2xl font-bold mb-4">License Status</h2>
        <div class="flex items-center justify-between">
          <div>
            <p class="font-semibold">
              {$license.valid ? '✅ Pro License Active' : '🆓 Free Version'}
            </p>
            <p class="text-sm text-gray-400 mt-1">
              {#if $license.valid}
                License Key: {$license.key?.substring(0, 16)}...
                <br />
                Activated: {$license.activatedAt ? new Date($license.activatedAt).toLocaleDateString() : 'N/A'}
              {:else}
                Limited to 3 agents and 5 memories. Upgrade to Pro for unlimited access.
              {/if}
            </p>
          </div>
          <div class="flex gap-2">
            {#if $license.valid}
              <button
                on:click={deactivateLicenseKey}
                class="px-4 py-2 glass hover:bg-red-500/20 rounded-lg text-sm"
              >
                Deactivate
              </button>
            {:else}
              <button
                on:click={unlockPro}
                class="px-6 py-2 bg-gradient-to-r from-nebula-primary to-nebula-accent hover:opacity-90 rounded-lg font-semibold"
              >
                Activate License
              </button>
            {/if}
          </div>
        </div>
        {#if $license.valid}
          <div class="mt-4 bg-nebula-primary/10 border border-nebula-primary/30 rounded-lg p-4">
            <p class="text-sm text-gray-400 mb-2">Pro Features Unlocked:</p>
            <ul class="text-sm text-gray-300 space-y-1">
              <li>✓ Unlimited agent swarms</li>
              <li>✓ Unlimited memory files</li>
              <li>✓ Priority support</li>
              <li>✓ Future updates included</li>
            </ul>
          </div>
        {/if}
      </section>

      <!-- Sync Status Banner -->
      {#if syncStatus === 'success'}
        <div class="bg-green-500/10 border border-green-500/30 rounded-lg p-4 mb-6 flex items-center gap-3">
          <span class="text-green-500 text-xl">&#10003;</span>
          <p class="text-green-400 font-semibold">{syncMessage}</p>
        </div>
      {:else if syncStatus === 'error'}
        <div class="bg-yellow-500/10 border border-yellow-500/30 rounded-lg p-4 mb-6 flex items-center gap-3">
          <span class="text-yellow-500 text-xl">&#9888;</span>
          <p class="text-yellow-400">{syncMessage}</p>
        </div>
      {/if}

      <!-- Save Button -->
      <div class="flex justify-between items-center">
        <button
          on:click={runSetupWizard}
          class="px-6 py-3 glass hover:bg-nebula-card rounded-lg font-semibold"
        >
          Run Setup Wizard
        </button>
        <button
          on:click={saveSettings}
          disabled={syncing}
          class="px-8 py-3 bg-nebula-primary hover:bg-nebula-primaryLight disabled:opacity-50 rounded-lg font-semibold text-lg"
        >
          {syncing ? 'Syncing...' : 'Save & Sync'}
        </button>
      </div>

      <!-- Info -->
      <div class="mt-8 text-center text-gray-500 text-sm">
        <p>NullClaw Nexus v1.0.0</p>
        <p class="mt-1">Built with ❤️ for the NullClaw community</p>
      </div>
    </div>
  </div>
{/if}
