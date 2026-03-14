<svelte:options runes={false} />

<script lang="ts">
  import { onMount } from 'svelte';

  interface Tool {
    id: string;
    name: string;
    desc: string;
    enabled: boolean;
    category: 'search' | 'compute' | 'data' | 'system' | 'custom';
  }

  let tools: Tool[] = [
    { id: 'web-search', name: 'Web Search', desc: 'Search Google/Brave for real-time information', enabled: false, category: 'search' },
    { id: 'calc', name: 'Calculator', desc: 'Perform complex math and arithmetic execution', enabled: true, category: 'compute' },
    { id: 'code-exec', name: 'Code Execution', desc: 'Run Python/JavaScript code snippets in sandboxed environment', enabled: false, category: 'compute' },
    { id: 'file-read', name: 'File Reader', desc: 'Read and parse local files (PDF, CSV, TXT, JSON)', enabled: false, category: 'data' },
    { id: 'web-scrape', name: 'Web Scraper', desc: 'Extract structured data from web pages', enabled: false, category: 'search' },
    { id: 'shell-exec', name: 'Shell Command', desc: 'Execute whitelisted shell commands on the host', enabled: false, category: 'system' },
    { id: 'image-gen', name: 'Image Generation', desc: 'Generate images via DALL-E, Stable Diffusion, or local models', enabled: false, category: 'compute' },
    { id: 'memory-store', name: 'Memory Store', desc: 'Save and retrieve persistent context across sessions', enabled: true, category: 'data' }
  ];

  let showAddTool = false;
  let newTool = { name: '', desc: '', category: 'custom' as Tool['category'] };
  let filter: string = 'all';

  const categories: Record<string, string> = {
    search: 'Search',
    compute: 'Compute',
    data: 'Data',
    system: 'System',
    custom: 'Custom'
  };

  const categoryColors: Record<string, string> = {
    search: 'text-blue-400 border-blue-500/30 bg-blue-500/10',
    compute: 'text-purple-400 border-purple-500/30 bg-purple-500/10',
    data: 'text-green-400 border-green-500/30 bg-green-500/10',
    system: 'text-orange-400 border-orange-500/30 bg-orange-500/10',
    custom: 'text-nebula-accent border-nebula-accent/30 bg-nebula-accent/10'
  };

  function toggleTool(id: string) {
    tools = tools.map(t => t.id === id ? { ...t, enabled: !t.enabled } : t);
    saveTools();
  }

  function removeTool(id: string) {
    if (confirm('Remove this tool from the library?')) {
      tools = tools.filter(t => t.id !== id);
      saveTools();
    }
  }

  function addCustomTool() {
    if (!newTool.name.trim()) return;
    const id = `custom-${Date.now()}`;
    tools = [...tools, {
      id,
      name: newTool.name.trim(),
      desc: newTool.desc.trim() || 'Custom tool',
      enabled: true,
      category: 'custom'
    }];
    newTool = { name: '', desc: '', category: 'custom' };
    showAddTool = false;
    saveTools();
  }

  function saveTools() {
    if (typeof localStorage !== 'undefined') {
      localStorage.setItem('nullclaw_tools', JSON.stringify(tools));
    }
  }

  function loadTools() {
    if (typeof localStorage === 'undefined') return;
    const saved = localStorage.getItem('nullclaw_tools');
    if (saved) {
      try {
        tools = JSON.parse(saved);
      } catch {
        // Use defaults
      }
    }
  }

  $: filteredTools = filter === 'all' ? tools : tools.filter(t => t.category === filter);
  $: enabledCount = tools.filter(t => t.enabled).length;

  onMount(() => {
    loadTools();
  });
</script>

<div class="min-h-screen p-8">
  <div class="max-w-5xl mx-auto">
    <!-- Header -->
    <header class="mb-8 flex items-center justify-between">
      <div class="flex items-center gap-4">
        <a href="/" class="glass px-4 py-2 rounded-lg hover:bg-nebula-primary/20 transition-all">
          ← Back
        </a>
        <div>
          <h1 class="text-3xl font-bold">Tool Library</h1>
          <p class="text-gray-400 text-sm mt-1">Manage and approve tool calls for your AI agents</p>
        </div>
      </div>
      <button
        on:click={() => showAddTool = !showAddTool}
        class="glass px-4 py-2 rounded-lg hover:bg-nebula-primary/20 text-nebula-accent font-semibold transition-all"
      >
        + Register Custom Tool
      </button>
    </header>

    <!-- Add Custom Tool Panel -->
    {#if showAddTool}
      <div class="glass p-6 mb-6 border border-nebula-accent/30">
        <h3 class="text-lg font-bold mb-4">Register Custom Tool</h3>
        <div class="grid grid-cols-1 md:grid-cols-2 gap-4 mb-4">
          <div>
            <label class="block text-sm text-gray-400 mb-1">Tool Name</label>
            <input
              bind:value={newTool.name}
              placeholder="e.g. My API Caller"
              class="w-full px-4 py-2 glass rounded-lg bg-transparent border border-gray-700 focus:border-nebula-accent outline-none"
            />
          </div>
          <div>
            <label class="block text-sm text-gray-400 mb-1">Description</label>
            <input
              bind:value={newTool.desc}
              placeholder="What does this tool do?"
              class="w-full px-4 py-2 glass rounded-lg bg-transparent border border-gray-700 focus:border-nebula-accent outline-none"
            />
          </div>
        </div>
        <div class="flex gap-2">
          <button
            on:click={addCustomTool}
            class="px-6 py-2 bg-nebula-accent/20 border border-nebula-accent/50 rounded-lg text-nebula-accent font-semibold hover:bg-nebula-accent/30 transition-all"
          >
            Add Tool
          </button>
          <button
            on:click={() => showAddTool = false}
            class="px-6 py-2 glass rounded-lg text-gray-400 hover:text-white transition-all"
          >
            Cancel
          </button>
        </div>
      </div>
    {/if}

    <!-- Filter Bar -->
    <div class="flex items-center gap-3 mb-6">
      <span class="text-sm text-gray-400">Filter:</span>
      <button
        on:click={() => filter = 'all'}
        class={`px-3 py-1 rounded-lg text-sm transition-all ${filter === 'all' ? 'bg-nebula-accent/20 text-nebula-accent border border-nebula-accent/30' : 'glass text-gray-400 hover:text-white'}`}
      >
        All ({tools.length})
      </button>
      {#each Object.entries(categories) as [key, label]}
        {@const count = tools.filter(t => t.category === key).length}
        {#if count > 0}
          <button
            on:click={() => filter = key}
            class={`px-3 py-1 rounded-lg text-sm transition-all ${filter === key ? categoryColors[key] + ' border' : 'glass text-gray-400 hover:text-white'}`}
          >
            {label} ({count})
          </button>
        {/if}
      {/each}
      <div class="ml-auto text-sm text-gray-500">
        {enabledCount} of {tools.length} enabled
      </div>
    </div>

    <!-- Tools Grid -->
    <div class="grid gap-4">
      {#each filteredTools as tool (tool.id)}
        <div class="glass hover:scale-[1.01] transition-all">
          <div class="flex items-center justify-between p-5">
            <div class="flex items-center gap-4">
              <div class={`w-2 h-2 rounded-full ${tool.enabled ? 'bg-green-400' : 'bg-gray-600'}`}></div>
              <div>
                <div class="flex items-center gap-2">
                  <h3 class="font-bold text-lg">{tool.name}</h3>
                  <span class={`text-xs px-2 py-0.5 rounded border ${categoryColors[tool.category]}`}>
                    {categories[tool.category]}
                  </span>
                </div>
                <p class="text-sm text-gray-400 mt-1">{tool.desc}</p>
              </div>
            </div>
            <div class="flex items-center gap-3">
              <button
                on:click={() => toggleTool(tool.id)}
                class={`px-4 py-2 rounded-lg text-sm font-semibold transition-all ${tool.enabled ? 'bg-green-500/20 text-green-400 border border-green-500/30 hover:bg-green-500/30' : 'glass text-gray-400 hover:text-white'}`}
              >
                {tool.enabled ? 'Enabled' : 'Disabled'}
              </button>
              {#if tool.category === 'custom'}
                <button
                  on:click={() => removeTool(tool.id)}
                  class="px-3 py-2 glass rounded-lg text-red-400 hover:bg-red-500/20 text-sm transition-all"
                >
                  Remove
                </button>
              {/if}
            </div>
          </div>
        </div>
      {/each}
    </div>

    {#if filteredTools.length === 0}
      <div class="glass p-12 text-center">
        <p class="text-gray-400">No tools found in this category.</p>
      </div>
    {/if}

    <!-- Info Banner -->
    <div class="glass p-4 mt-8 text-center text-sm text-gray-500">
      Tools are stored locally. Enabled tools will be available to AI agents during chat sessions.
      <br />
      Future versions will support tool approval workflows, execution logs, and gateway-side registration.
    </div>
  </div>
</div>
