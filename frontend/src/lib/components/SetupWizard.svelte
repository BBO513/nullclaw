<svelte:options runes={false} />

<script lang="ts">
  import { gatewayConfig, providers, ollamaModels, openaiModels, claudeModels } from '$lib/stores/gateway';
  import { license, activateLicense } from '$lib/stores/license';
  import { GatewayAPI } from '$lib/api/gateway';

  export let show = false;
  export let onClose: () => void = () => {};
  
  let currentStep = 1;
  let totalSteps = 6;
  
  // Step 2: Gateway Connection
  let gatewayUrl = '';
  let checkingGateway = false;
  let gatewayConnected = false;
  
  // Step 3: Pairing
  let pairingCode = '';
  let pairing = false;
  let paired = false;
  
  // Step 4: Provider Selection
  let selectedProvider = '';
  let detectingOllama = false;
  let ollamaDetected = false;
  let availableOllamaModels: string[] = [];
  
  // Step 5: Model Selection
  let selectedModel = '';
  
  // Step 6: License (optional)
  let licenseKey = '';
  let activatingLicense = false;
  
  let error = '';
  let loading = false;
  let loadingMessage = '';
  let modelList: string[] = [];

  // Initialize values when wizard opens
  $: if (show) {
    gatewayUrl = $gatewayConfig.url;
    selectedProvider = $gatewayConfig.provider;
    selectedModel = $gatewayConfig.model;
    updateModelList();
  }

  function updateModelList() {
    switch (selectedProvider) {
      case 'ollama':
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
  }

  $: {
    selectedProvider;
    updateModelList();
  }

  async function checkGateway() {
    checkingGateway = true;
    loading = true;
    loadingMessage = 'Connecting to gateway...';
    error = '';
    
    try {
      const api = new GatewayAPI(gatewayUrl);
      gatewayConnected = await api.checkHealth();
      
      if (gatewayConnected) {
        gatewayConfig.update(c => ({ ...c, url: gatewayUrl, connected: true }));
      } else {
        error = 'Could not connect to gateway. Please check the URL and ensure NullClaw is running.';
      }
    } catch (err) {
      error = 'Failed to connect to gateway';
      gatewayConnected = false;
    } finally {
      checkingGateway = false;
      loading = false;
    }
  }

  async function handlePair() {
    if (!pairingCode.trim()) {
      error = 'Please enter a pairing code';
      return;
    }

    pairing = true;
    loading = true;
    loadingMessage = 'Pairing with gateway...';
    error = '';

    try {
      const api = new GatewayAPI($gatewayConfig.url);
      const result = await api.pair(pairingCode);

      if (result && result.token) {
        gatewayConfig.update(c => ({
          ...c,
          bearerToken: result.token,
          paired: true,
          connected: true
        }));
        paired = true;
      } else {
        error = 'Invalid pairing code. Please check and try again.';
      }
    } catch (err) {
      error = 'Failed to pair with gateway';
    } finally {
      pairing = false;
      loading = false;
    }
  }

  function skipPairing() {
    // Skip pairing - user can pair later from settings
    // For creator/dev, just mark as paired with a placeholder token
    gatewayConfig.update(c => ({
      ...c,
      bearerToken: 'SKIP_PAIRING_TEMP_TOKEN',
      paired: true,
      connected: true
    }));
    paired = true;
    error = '';
  }

  async function detectOllama() {
    detectingOllama = true;
    loading = true;
    loadingMessage = 'Detecting Ollama models...';
    
    try {
      const api = new GatewayAPI();
      const models = await api.getOllamaModels();
      availableOllamaModels = models;
      ollamaDetected = models.length > 0;
      updateModelList();
    } catch {
      ollamaDetected = false;
    } finally {
      detectingOllama = false;
      loading = false;
    }
  }

  function handleActivateLicense() {
    if (!licenseKey.trim()) {
      return; // Skip if empty (optional step)
    }

    activatingLicense = true;
    loading = true;
    loadingMessage = 'Activating license...';
    error = '';

    setTimeout(() => {
      const success = activateLicense(licenseKey.trim().toUpperCase());
      
      if (!success) {
        error = 'Invalid license key format';
      }
      
      activatingLicense = false;
      loading = false;
    }, 500);
  }

  function next() {
    error = '';
    
    // Don't go past last step
    if (currentStep >= totalSteps) {
      return;
    }
    
    // Validation before moving to next step
    if (currentStep === 2 && !gatewayConnected) {
      error = 'Please connect to gateway first';
      return;
    }
    
    if (currentStep === 3 && !paired) {
      error = 'Please pair with gateway first';
      return;
    }
    
    if (currentStep === 4 && !selectedProvider) {
      error = 'Please select a provider';
      return;
    }
    
    if (currentStep === 5 && !selectedModel) {
      error = 'Please select a model';
      return;
    }
    
    currentStep++;
  }

  function back() {
    error = '';
    if (currentStep > 1) {
      currentStep--;
    }
  }

  function skip() {
    error = '';
    if (currentStep < totalSteps) {
      currentStep++;
    }
  }

  function finish() {
    // Save settings
    gatewayConfig.update(c => ({
      ...c,
      provider: selectedProvider,
      model: selectedModel
    }));
    
    // Mark setup as completed
    localStorage.setItem('setup-wizard-completed', 'true');
    
    // Close wizard
    show = false;
    
    // Celebrate!
    celebrate();
  }

  function celebrate() {
    console.log('🎉 Setup complete! Welcome to NullClaw Nexus!');
  }

  function close() {
    if (confirm('Are you sure you want to exit setup? You can run it again from Settings.')) {
      show = false;
    }
  }
</script>

{#if show}
  <div class="fixed inset-0 bg-black/90 flex items-center justify-center p-8 z-50">
    <div class="glass max-w-4xl w-full max-h-[90vh] overflow-y-auto p-8">
      <!-- Header -->
      <div class="flex items-center justify-between mb-8">
        <div>
          <h1 class="text-3xl font-bold">Setup Wizard</h1>
          <p class="text-gray-400 mt-1">Step {currentStep} of {totalSteps}</p>
        </div>
        <button
          on:click={close}
          class="text-gray-400 hover:text-white text-2xl"
        >
          ✕
        </button>
      </div>

      <!-- Progress Bar -->
      <div class="mb-8">
        <div class="h-2 bg-nebula-bg rounded-full overflow-hidden">
          <div 
            class="h-full bg-gradient-to-r from-nebula-primary to-nebula-accent transition-all duration-300"
            style="width: {(currentStep / totalSteps) * 100}%"
          ></div>
        </div>
      </div>

      <!-- Loading Overlay -->
      {#if loading}
        <div class="absolute inset-0 bg-black/50 flex items-center justify-center rounded-xl">
          <div class="text-center">
            <div class="text-6xl mb-4 animate-spin">⏳</div>
            <p class="text-xl font-semibold">{loadingMessage}</p>
          </div>
        </div>
      {/if}

      <!-- Step Content -->
      <div class="min-h-[400px]">
        {#if currentStep === 1}
          <!-- Step 1: Welcome -->
          <div class="text-center py-12">
            <div class="text-8xl mb-6">🚀</div>
            <h2 class="text-4xl font-bold mb-4">Welcome to NullClaw Nexus</h2>
            <p class="text-xl text-gray-400 mb-8">
              Let's get you set up in just a few steps
            </p>
            <div class="max-w-2xl mx-auto text-left space-y-4">
              <div class="flex items-start gap-4">
                <span class="text-3xl">🔌</span>
                <div>
                  <h3 class="font-bold">Connect to Gateway</h3>
                  <p class="text-sm text-gray-400">Link your NullClaw gateway</p>
                </div>
              </div>
              <div class="flex items-start gap-4">
                <span class="text-3xl">🤝</span>
                <div>
                  <h3 class="font-bold">Secure Pairing</h3>
                  <p class="text-sm text-gray-400">Establish encrypted connection</p>
                </div>
              </div>
              <div class="flex items-start gap-4">
                <span class="text-3xl">🤖</span>
                <div>
                  <h3 class="font-bold">Choose Your AI</h3>
                  <p class="text-sm text-gray-400">Select provider and model</p>
                </div>
              </div>
            </div>
          </div>

        {:else if currentStep === 2}
          <!-- Step 2: Gateway Connection -->
          <div>
            <h2 class="text-2xl font-bold mb-4">Connect to Gateway</h2>
            <p class="text-gray-400 mb-6">
              Enter your NullClaw gateway URL. The default is http://127.0.0.1:3000.
            </p>

            <div class="mb-6">
              <label for="gateway-url" class="block text-sm text-gray-400 mb-2">Gateway URL</label>
              <input
                id="gateway-url"
                type="text"
                bind:value={gatewayUrl}
                placeholder="http://127.0.0.1:3000"
                class="w-full glass px-4 py-3 rounded-lg focus:outline-none focus:ring-2 focus:ring-nebula-primary"
              />
            </div>

            <button
              on:click={checkGateway}
              disabled={checkingGateway}
              class="w-full px-6 py-3 bg-nebula-primary hover:bg-nebula-primaryLight disabled:opacity-50 rounded-lg font-semibold mb-4"
            >
              {checkingGateway ? 'Checking...' : 'Test Connection'}
            </button>

            {#if gatewayConnected}
              <div class="p-4 bg-green-500/10 border border-green-500/30 rounded-lg">
                <p class="text-green-500 font-semibold">✅ Connected successfully!</p>
              </div>
            {/if}
          </div>

        {:else if currentStep === 3}
          <!-- Step 3: Pairing -->
          <div>
            <h2 class="text-2xl font-bold mb-4">Pair with Gateway</h2>
            <p class="text-gray-400 mb-6">
              Enter the 6-digit pairing code from your NullClaw gateway terminal, or skip this step to pair later from Settings.
            </p>

            <div class="mb-6">
              <label for="pairing-code" class="block text-sm text-gray-400 mb-2">Pairing Code (Optional)</label>
              <input
                id="pairing-code"
                type="text"
                bind:value={pairingCode}
                placeholder="000000"
                maxlength="6"
                class="w-full glass px-4 py-3 rounded-lg text-center text-2xl tracking-widest focus:outline-none focus:ring-2 focus:ring-nebula-primary"
              />
            </div>

            <button
              on:click={handlePair}
              disabled={pairing || pairingCode.length !== 6}
              class="w-full px-6 py-3 bg-nebula-primary hover:bg-nebula-primaryLight disabled:opacity-50 rounded-lg font-semibold mb-4"
            >
              {pairing ? 'Pairing...' : 'Pair Now'}
            </button>

            <button
              on:click={skipPairing}
              class="w-full px-6 py-3 glass hover:bg-nebula-card rounded-lg font-semibold"
            >
              Skip Pairing (Pair Later)
            </button>

            {#if paired}
              <div class="p-4 bg-green-500/10 border border-green-500/30 rounded-lg mt-4">
                <p class="text-green-500 font-semibold">✅ Ready to continue!</p>
              </div>
            {/if}
          </div>

        {:else if currentStep === 4}
          <!-- Step 4: Provider Selection -->
          <div>
            <h2 class="text-2xl font-bold mb-4">Select LLM Provider</h2>
            <p class="text-gray-400 mb-6">
              Choose your AI provider. Ollama is recommended for local, private AI.
            </p>

            <button
              on:click={detectOllama}
              disabled={detectingOllama}
              class="w-full px-6 py-3 glass hover:bg-nebula-card disabled:opacity-50 rounded-lg font-semibold mb-6"
            >
              {detectingOllama ? 'Detecting...' : '🔍 Detect Ollama Models'}
            </button>

            {#if ollamaDetected}
              <div class="p-4 bg-green-500/10 border border-green-500/30 rounded-lg mb-6">
                <p class="text-green-500 font-semibold">✅ Found {availableOllamaModels.length} Ollama models</p>
              </div>
            {/if}

            <div class="space-y-3">
              {#each providers as provider}
                <button
                  on:click={() => selectedProvider = provider.id}
                  class={`w-full p-4 rounded-lg text-left transition-all ${selectedProvider === provider.id ? 'bg-nebula-primary border-2 border-nebula-primary' : 'glass hover:bg-nebula-card'}`}
                >
                  <div class="flex items-center justify-between">
                    <span class="font-semibold">{provider.name}</span>
                    {#if provider.priority}
                      <span class="text-yellow-500">⭐</span>
                    {/if}
                  </div>
                </button>
              {/each}
            </div>
          </div>

        {:else if currentStep === 5}
          <!-- Step 5: Model Selection -->
          <div>
            <h2 class="text-2xl font-bold mb-4">Select Model</h2>
            <p class="text-gray-400 mb-6">
              Choose the AI model you want to use with {selectedProvider}.
            </p>

            <div class="space-y-3">
              {#each modelList as model}
                <button
                  on:click={() => selectedModel = model}
                  class={`w-full p-4 rounded-lg text-left transition-all block ${selectedModel === model ? 'bg-nebula-primary border-2 border-nebula-primary' : 'glass hover:bg-nebula-card'}`}
                >
                  <span class="font-semibold font-mono block">{model}</span>
                </button>
              {/each}
            </div>
          </div>

        {:else if currentStep === 6}
          <!-- Step 6: License (Optional) -->
          <div>
            <div class="flex items-center gap-2 mb-4">
              <h2 class="text-2xl font-bold">Activate License</h2>
              <span class="px-3 py-1 bg-gray-500/20 text-gray-400 text-sm rounded-full">Optional</span>
            </div>
            <p class="text-gray-400 mb-6">
              Have a pro license? Enter it now to unlock unlimited features. You can skip this and use the free tier or activate later from Settings.
            </p>

            <div class="mb-6">
              <label for="license-key" class="block text-sm text-gray-400 mb-2">License Key</label>
              <input
                id="license-key"
                type="text"
                bind:value={licenseKey}
                placeholder="NULLCLAW-XXXX-XXXX-XXXX"
                class="w-full glass px-4 py-3 rounded-lg font-mono focus:outline-none focus:ring-2 focus:ring-nebula-primary"
              />
            </div>

            <button
              on:click={handleActivateLicense}
              disabled={activatingLicense || !licenseKey.trim()}
              class="w-full px-6 py-3 bg-gradient-to-r from-nebula-primary to-nebula-accent hover:opacity-90 disabled:opacity-50 rounded-lg font-semibold mb-6"
            >
              {activatingLicense ? 'Activating...' : 'Activate License'}
            </button>

            <!-- Free vs Pro -->
            <div class="grid grid-cols-2 gap-4">
              <div class="glass p-4 rounded-lg">
                <h3 class="font-bold mb-2 text-gray-400">Free Tier</h3>
                <ul class="text-sm space-y-1">
                  <li>• 3 agents max</li>
                  <li>• 5 memories max</li>
                  <li>• All core features</li>
                </ul>
              </div>
              <div class="bg-gradient-to-br from-nebula-primary/20 to-nebula-accent/20 p-4 rounded-lg border-2 border-nebula-primary/30">
                <h3 class="font-bold mb-2 text-nebula-primary">Pro ($9.99)</h3>
                <ul class="text-sm space-y-1">
                  <li>• Unlimited agents</li>
                  <li>• Unlimited memories</li>
                  <li>• Priority support</li>
                </ul>
              </div>
            </div>

            <p class="text-xs text-center text-gray-500 mt-4">
              Purchase at <a href="https://gumroad.com/nullclaw" target="_blank" class="text-nebula-accent hover:underline">gumroad.com/nullclaw</a>
            </p>
          </div>
        {/if}
      </div>

      <!-- Error Message -->
      {#if error}
        <div class="mt-6 p-4 bg-red-500/10 border border-red-500/30 rounded-lg">
          <p class="text-red-500">{error}</p>
        </div>
      {/if}

      <!-- Navigation -->
      <div class="flex gap-4 mt-8">
        {#if currentStep > 1}
          <button
            on:click={back}
            disabled={loading}
            class="px-6 py-3 glass hover:bg-nebula-card disabled:opacity-50 rounded-lg font-semibold"
          >
            Back
          </button>
        {/if}

        <div class="flex-1"></div>

        {#if currentStep === 6}
          <button
            on:click={skip}
            disabled={loading}
            class="px-6 py-3 glass hover:bg-nebula-card disabled:opacity-50 rounded-lg font-semibold"
          >
            Skip
          </button>
          <button
            on:click={finish}
            disabled={loading}
            class="px-8 py-3 bg-gradient-to-r from-nebula-primary to-nebula-accent hover:opacity-90 disabled:opacity-50 rounded-lg font-semibold"
          >
            Finish
          </button>
        {:else if currentStep === 1}
          <button
            on:click={next}
            class="px-8 py-3 bg-nebula-primary hover:bg-nebula-primaryLight rounded-lg font-semibold"
          >
            Get Started
          </button>
        {:else}
          <button
            on:click={next}
            disabled={loading}
            class="px-8 py-3 bg-nebula-primary hover:bg-nebula-primaryLight disabled:opacity-50 rounded-lg font-semibold"
          >
            Next
          </button>
        {/if}
      </div>
    </div>
  </div>
{/if}
