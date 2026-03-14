<script lang="ts">
  import { onMount } from 'svelte';
  import { memories, type Memory, toggleMemoryActive, setAllMemoriesActive } from '$lib/stores/memories';
  import { gatewayConfig } from '$lib/stores/gateway';
  import { license } from '$lib/stores/license';
  import { GatewayAPI } from '$lib/api/gateway';

  let mounted = $state(false);
  let dragOver = $state(false);
  let selectedMemory: Memory | null = $state(null);
  let editContent = $state('');
  let injecting = $state(false);
  let toastMessage = $state('');
  let toastType: 'success' | 'error' = $state('success');
  let showToast = $state(false);

  onMount(() => {
    mounted = true;
  });

  function handleDrop(e: DragEvent) {
    e.preventDefault();
    dragOver = false;

    // Check license for unlimited memories
    if (!$license.valid && $memories.length >= 5) {
      showToastMessage('⚠️ Free version limited to 5 memories. Upgrade to Pro for unlimited memories.', 'error');
      return;
    }

    const files = e.dataTransfer?.files;
    if (!files) return;

    Array.from(files).forEach(async (file) => {
      if (file.type === 'text/plain' || file.name.endsWith('.md') || file.name.endsWith('.txt')) {
        const content = await file.text();
        const newMemory: Memory = {
          id: crypto.randomUUID(),
          name: file.name,
          content,
          type: file.name.includes('prompt') ? 'prompt' : 'knowledge',
          size: file.size,
          createdAt: new Date(),
          active: false,
        };
        memories.update(m => [...m, newMemory]);
        showToastMessage(`✅ Uploaded "${file.name}"`, 'success');
      } else {
        showToastMessage(`❌ Unsupported file type: ${file.name}`, 'error');
      }
    });
  }

  function handleDragOver(e: DragEvent) {
    e.preventDefault();
    dragOver = true;
  }

  function handleDragLeave() {
    dragOver = false;
  }

  function editMemory(memory: Memory) {
    selectedMemory = memory;
    editContent = memory.content;
  }

  function saveMemory() {
    if (!selectedMemory) return;
    const memoryId = selectedMemory.id;
    memories.update(m => m.map(mem => 
      mem.id === memoryId 
        ? { ...mem, content: editContent, size: new Blob([editContent]).size }
        : mem
    ));
    selectedMemory = null;
    showToastMessage('✅ Memory updated', 'success');
  }

  function deleteMemory(id: string) {
    if (confirm('Are you sure you want to delete this memory?')) {
      memories.update(m => m.filter(mem => mem.id !== id));
      showToastMessage('✅ Memory deleted', 'success');
    }
  }

  async function injectMemory(memory: Memory) {
    if (!$gatewayConfig.connected) {
      showToastMessage('❌ Gateway is not connected. Please check Settings.', 'error');
      return;
    }

    if (!$gatewayConfig.paired) {
      showToastMessage('❌ Gateway is not paired. Please pair in Settings.', 'error');
      return;
    }

    injecting = true;

    try {
      const api = new GatewayAPI($gatewayConfig.url, $gatewayConfig.bearerToken);
      const result = await api.injectMemory(
        $gatewayConfig.model || 'llama3.1',
        memory.name,
        memory.content
      );

      if (result.success) {
        showToastMessage(`✅ Injected "${memory.name}" to agent`, 'success');
      } else {
        showToastMessage(`❌ Failed: ${result.message}`, 'error');
      }
    } catch (error) {
      const errorMsg = error instanceof Error ? error.message : String(error);
      showToastMessage(`❌ Error: ${errorMsg}`, 'error');
    } finally {
      injecting = false;
    }
  }

  function showToastMessage(message: string, type: 'success' | 'error') {
    toastMessage = message;
    toastType = type;
    showToast = true;
    setTimeout(() => {
      showToast = false;
    }, 4000);
  }
</script>

{#if !mounted}
  <div class="min-h-screen flex items-center justify-center">
    <div class="text-center">
      <div class="text-4xl mb-4">⏳</div>
      <p class="text-gray-400">Loading...</p>
    </div>
  </div>
{:else}
  <div class="min-h-screen p-8">
    <div class="max-w-7xl mx-auto">
      <!-- Header -->
      <header class="mb-8">
        <a href="/" class="glass px-4 py-2 rounded-lg hover:bg-nebula-primary/20 transition-all inline-flex items-center gap-2 mb-4">
          <span class="text-xl">←</span>
          <span>Back</span>
        </a>
        <h1 class="text-4xl font-bold mt-4">Memory Vault</h1>
        <p class="text-gray-400 mt-2">Upload and manage prompts & knowledge files</p>
        {#if !$license.valid}
          <p class="text-sm text-yellow-500 mt-2">Free tier: {$memories.length}/5 memories used</p>
        {/if}
        
        <!-- Active memories summary -->
        {#if $memories.length > 0}
          {@const activeCount = $memories.filter(m => m.active).length}
          <div class="flex items-center gap-4 mt-4">
            <span class="text-sm text-nebula-accent">
              {activeCount}/{$memories.length} memories active in chat context
            </span>
            <button
              on:click={() => setAllMemoriesActive(true)}
              class="text-xs px-3 py-1 bg-nebula-accent/20 hover:bg-nebula-accent/30 rounded transition-all"
            >
              Activate All
            </button>
            <button
              on:click={() => setAllMemoriesActive(false)}
              class="text-xs px-3 py-1 bg-gray-500/20 hover:bg-gray-500/30 rounded transition-all"
            >
              Deactivate All
            </button>
          </div>
        {/if}
      </header>

      <!-- Upload Zone -->
      <div
        role="button"
        tabindex="0"
        class={`glass p-12 mb-8 border-2 border-dashed ${dragOver ? 'border-nebula-accent bg-nebula-glow' : 'border-nebula-primary/30'} rounded-xl text-center transition-all cursor-pointer`}
        on:drop={handleDrop}
        on:dragover={handleDragOver}
        on:dragleave={handleDragLeave}
      >
        <div class="text-6xl mb-4">📁</div>
        <h3 class="text-xl font-bold mb-2">Drop files here</h3>
        <p class="text-gray-400">Supports .txt and .md files</p>
      </div>

      <!-- Memory List -->
      <div class="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-6">
        {#each $memories as memory}
          <div class={`glass p-6 border-2 transition-all ${memory.active ? 'border-nebula-accent/50 shadow-lg shadow-nebula-accent/10' : 'border-transparent'}`}>
            <div class="flex items-start justify-between mb-4">
              <div class="flex-1">
                <h3 class="font-bold text-lg truncate">{memory.name}</h3>
                <div class="flex gap-2 mt-2">
                  <span class={`text-xs px-2 py-1 rounded ${memory.type === 'prompt' ? 'bg-nebula-primary/20 text-nebula-primary' : 'bg-nebula-accent/20 text-nebula-accent'}`}>
                    {memory.type}
                  </span>
                  <span class="text-xs text-gray-400">{(memory.size / 1024).toFixed(1)} KB</span>
                  {#if memory.active}
                    <span class="text-xs px-2 py-1 rounded bg-green-500/20 text-green-400">Active</span>
                  {/if}
                </div>
              </div>
              <!-- Active toggle -->
              <button
                on:click={() => toggleMemoryActive(memory.id)}
                class={`w-12 h-6 rounded-full transition-all relative ${memory.active ? 'bg-nebula-accent' : 'bg-gray-600'}`}
                title={memory.active ? 'Deactivate from chat context' : 'Activate in chat context'}
              >
                <div class={`w-5 h-5 rounded-full bg-white absolute top-0.5 transition-all ${memory.active ? 'left-6' : 'left-0.5'}`}></div>
              </button>
            </div>

            <div class="text-sm text-gray-400 mb-4 line-clamp-3">
              {memory.content.substring(0, 150)}...
            </div>

            <div class="flex gap-2">
              <button
                on:click={() => editMemory(memory)}
                class="flex-1 px-3 py-2 bg-nebula-primary/20 hover:bg-nebula-primary/30 rounded text-sm"
              >
                Edit
              </button>
              <button
                on:click={() => injectMemory(memory)}
                disabled={injecting || !$gatewayConfig.connected}
                class="flex-1 px-3 py-2 bg-nebula-accent/20 hover:bg-nebula-accent/30 disabled:opacity-50 disabled:cursor-not-allowed rounded text-sm"
              >
                {injecting ? 'Injecting...' : 'Inject to Gateway'}
              </button>
              <button
                on:click={() => deleteMemory(memory.id)}
                class="px-3 py-2 bg-red-500/20 hover:bg-red-500/30 rounded text-sm"
              >
                🗑️
              </button>
            </div>
          </div>
        {/each}

        {#if $memories.length === 0}
          <div class="col-span-full text-center text-gray-500 py-12">
            <p>No memories yet. Drop some files above to get started!</p>
          </div>
        {/if}
      </div>
    </div>
  </div>

  <!-- Edit Modal -->
  {#if selectedMemory}
    <div class="fixed inset-0 bg-black/80 flex items-center justify-center p-8 z-50">
      <div class="glass max-w-4xl w-full max-h-[80vh] flex flex-col">
        <div class="p-6 border-b border-nebula-primary/20">
          <h2 class="text-2xl font-bold">{selectedMemory.name}</h2>
        </div>
        <div class="flex-1 overflow-y-auto p-6">
          <textarea
            bind:value={editContent}
            class="w-full h-full min-h-[400px] bg-nebula-bg/50 border border-nebula-primary/20 rounded-lg p-4 font-mono text-sm focus:outline-none focus:ring-2 focus:ring-nebula-primary"
          ></textarea>
        </div>
        <div class="p-6 border-t border-nebula-primary/20 flex gap-4 justify-end">
          <button
            on:click={() => selectedMemory = null}
            class="px-6 py-2 glass hover:bg-nebula-card rounded-lg"
          >
            Cancel
          </button>
          <button
            on:click={saveMemory}
            class="px-6 py-2 bg-nebula-primary hover:bg-nebula-primaryLight rounded-lg font-semibold"
          >
            Save Changes
          </button>
        </div>
      </div>
    </div>
  {/if}

  <!-- Toast Notification -->
  {#if showToast}
    <div class="fixed bottom-8 right-8 z-50 animate-slide-up">
      <div class={`glass px-6 py-4 rounded-lg border-2 ${toastType === 'success' ? 'border-green-500/50 bg-green-500/10' : 'border-red-500/50 bg-red-500/10'} min-w-[300px]`}>
        <p class={`font-semibold ${toastType === 'success' ? 'text-green-500' : 'text-red-500'}`}>
          {toastMessage}
        </p>
      </div>
    </div>
  {/if}
{/if}

<style>
  @keyframes slide-up {
    from {
      transform: translateY(100px);
      opacity: 0;
    }
    to {
      transform: translateY(0);
      opacity: 1;
    }
  }

  .animate-slide-up {
    animation: slide-up 0.3s ease-out;
  }
</style>
