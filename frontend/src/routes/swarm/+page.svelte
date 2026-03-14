<svelte:options runes={false} />

<script lang="ts">
  import { onMount } from 'svelte';
  import { gatewayConfig } from '$lib/stores/gateway';
  import { GatewayAPI } from '$lib/api/gateway';
  
  // Import custom node components
  import InputNode from '$lib/components/nodes/InputNode.svelte';
  import AgentNode from '$lib/components/nodes/AgentNode.svelte';
  import OutputNode from '$lib/components/nodes/OutputNode.svelte';

  // State management - Svelte 4 style (no runes)
  let mounted = false;
  let loaded = false;
  let loadError: string | null = null;
  let usingMockData = true;
  let fetchingFromGateway = false;
  let forceLoaded = false;
  
  // SvelteFlow components (dynamically loaded)
  let SvelteFlow: any = null;
  let Background: any = null;
  let Controls: any = null;
  
  // Custom node types for SvelteFlow
  const nodeTypes = {
    input: InputNode,
    agent: AgentNode,
    output: OutputNode,
    default: AgentNode // Fallback to agent node for default type
  };
  
  // Default mock data
  const DEFAULT_MOCK_NODES = [
    {
      id: 'input',
      type: 'input',
      data: { label: '📥 User Input', role: 'input', model: 'llama3.1' },
      position: { x: 100, y: 100 },
    },
    {
      id: 'agent',
      type: 'agent',
      data: { label: '🤖 Main Agent', role: 'coordinator', model: 'anthropic/claude-sonnet-4' },
      position: { x: 400, y: 200 },
    },
    {
      id: 'output',
      type: 'output',
      data: { label: '📤 Output Processor', role: 'output', model: 'llama3.1' },
      position: { x: 700, y: 100 },
    },
  ];

  const DEFAULT_MOCK_EDGES = [
    { id: 'e1', source: 'input', target: 'agent', type: 'smoothstep' },
    { id: 'e2', source: 'agent', target: 'output', type: 'smoothstep' },
  ];
  
  // Swarm data - will be loaded from localStorage or gateway
  let nodes: any[] = [];
  let edges: any[] = [];

  let exportFormat: 'json' | 'yaml' = 'json';
  let showExportModal = false;
  let exporting = false;
  let toastMessage = '';
  let toastType: 'success' | 'error' = 'success';
  let showToast = false;

  // Node editor state
  let editingNode: any = null;
  let editNodeLabel = '';
  let editNodeRole = '';
  let editNodeModel = '';
  let showNodeEditor = false;

  // Swarm execution state
  let running = false;
  let runLog: Array<{ nodeId: string; label: string; status: 'pending' | 'running' | 'done' | 'error'; message?: string }> = [];
  let showRunPanel = false;
  let deploying = false;

  // Load swarm from localStorage
  function loadFromLocalStorage() {
    if (typeof localStorage === 'undefined') return false;
    
    try {
      const savedNodes = localStorage.getItem('swarm_nodes');
      const savedEdges = localStorage.getItem('swarm_edges');
      
      if (savedNodes && savedEdges) {
        nodes = JSON.parse(savedNodes);
        edges = JSON.parse(savedEdges);
        console.log('✅ Loaded swarm from localStorage:', nodes.length, 'nodes,', edges.length, 'edges');
        return true;
      }
    } catch (error) {
      console.error('Failed to load from localStorage:', error);
    }
    
    return false;
  }

  // Save swarm to localStorage
  function saveToLocalStorage() {
    if (typeof localStorage === 'undefined') return;
    
    try {
      localStorage.setItem('swarm_nodes', JSON.stringify(nodes));
      localStorage.setItem('swarm_edges', JSON.stringify(edges));
      console.log('💾 Saved swarm to localStorage');
    } catch (error) {
      console.error('Failed to save to localStorage:', error);
    }
  }

  // Fetch swarm config from gateway
  async function fetchFromGateway() {
    if (!$gatewayConfig.connected || !$gatewayConfig.paired) {
      console.log('ℹ️ Gateway not connected - skipping fetch');
      return false;
    }

    fetchingFromGateway = true;
    console.log('🔄 Fetching swarm config from gateway:', `${$gatewayConfig.url}/swarm/config`);

    try {
      const response = await fetch(`${$gatewayConfig.url}/swarm/config`, {
        headers: {
          'Authorization': `Bearer ${$gatewayConfig.bearerToken}`
        },
        signal: AbortSignal.timeout(5000)
      });

      if (response.ok) {
        const data = await response.json();
        console.log('✅ Gateway response:', data);

        // Parse gateway response format
        if (data.nodes && Array.isArray(data.nodes)) {
          // Direct nodes/edges format
          nodes = data.nodes;
          edges = data.edges || [];
          console.log('✅ Loaded swarm from gateway:', nodes.length, 'nodes,', edges.length, 'edges');
          usingMockData = false;
          saveToLocalStorage();
          fetchingFromGateway = false;
          return true;
        } else if (data.agents && Array.isArray(data.agents)) {
          // Legacy agents/connections format
          nodes = data.agents.map((agent: any, idx: number) => ({
            id: agent.id || `agent-${idx}`,
            type: agent.type || 'default',
            data: { 
              label: agent.name || agent.label || `Agent ${idx + 1}`, 
              role: agent.role || 'worker',
              model: agent.model || 'llama3.1'
            },
            position: agent.position || { x: 100 + idx * 200, y: 100 + (idx % 2) * 100 }
          }));
          
          if (data.connections && Array.isArray(data.connections)) {
            edges = data.connections.map((conn: any, idx: number) => ({
              id: conn.id || `e-${idx}`,
              source: conn.from || conn.source,
              target: conn.to || conn.target,
              type: 'smoothstep'
            }));
          }
          
          console.log('✅ Loaded swarm from gateway (legacy format):', nodes.length, 'agents');
          usingMockData = false;
          saveToLocalStorage();
          fetchingFromGateway = false;
          return true;
        }
      } else if (response.status === 404) {
        console.log('ℹ️ Gateway /swarm/config endpoint not found (404) - using fallback');
        showToastMessage('ℹ️ No saved swarm - starting fresh', 'success');
        fetchingFromGateway = false;
        return false;
      } else {
        console.warn('⚠️ Gateway returned', response.status, '- using fallback');
        fetchingFromGateway = false;
        return false;
      }
    } catch (error) {
      if (error instanceof Error && error.name === 'AbortError') {
        console.warn('⚠️ Gateway fetch timeout - using fallback');
      } else {
        console.log('ℹ️ Gateway fetch error:', error);
      }
      fetchingFromGateway = false;
      return false;
    }

    fetchingFromGateway = false;
    return false;
  }

  onMount(async () => {
    console.log('🔧 Swarm Forge mounted');
    
    mounted = true;
    
    // Priority 1: Try to load from localStorage first
    const loadedFromStorage = loadFromLocalStorage();
    
    if (loadedFromStorage) {
      console.log('✅ Using swarm from localStorage');
      usingMockData = false;
    } else {
      // Priority 2: Try to fetch from gateway
      const loadedFromGateway = await fetchFromGateway();
      
      if (!loadedFromGateway) {
        // Priority 3: Fallback to mock data
        console.log('ℹ️ Using default mock data');
        nodes = [...DEFAULT_MOCK_NODES];
        edges = [...DEFAULT_MOCK_EDGES];
        usingMockData = true;
        saveToLocalStorage();
        showToastMessage('ℹ️ No saved swarm - starting fresh', 'success');
      }
    }

    // Debug log after data is loaded
    console.log('📊 States after data load:', { 
      fetchingFromGateway, 
      loaded, 
      mounted,
      forceLoaded,
      nodesLength: nodes.length,
      edgesLength: edges.length 
    });
    
    // Load SvelteFlow components
    try {
      console.log('📦 Loading @xyflow/svelte...');
      const startTime = Date.now();
      
      const module = await import('@xyflow/svelte');
      SvelteFlow = module.SvelteFlow;
      Background = module.Background;
      Controls = module.Controls;
      
      await import('@xyflow/svelte/dist/style.css');
      
      const loadTime = Date.now() - startTime;
      console.log(`✅ SvelteFlow loaded in ${loadTime}ms`);
      console.log('✅ Components:', { SvelteFlow: !!SvelteFlow, Background: !!Background, Controls: !!Controls });
      
      // CRITICAL: Set loaded = true here to show canvas
      loaded = true;
      fetchingFromGateway = false;
      forceLoaded = false;
      
      // Force render after components loaded
      console.log('🎨 Forcing canvas render - components ready');
      console.log('📊 Final swarm state:', { 
        nodes: nodes.length, 
        edges: edges.length,
        nodesArray: nodes,
        edgesArray: edges,
        SvelteFlow: !!SvelteFlow,
        Background: !!Background,
        Controls: !!Controls,
        loaded: true,
        forceLoaded: false,
        fetchingFromGateway: false
      });
      
    } catch (error) {
      console.error('❌ Failed to load SvelteFlow:', error);
      loadError = error instanceof Error ? error.message : String(error);
      loaded = true; // Show error state
      fetchingFromGateway = false;
    }
  });

  function addAgent() {
    const newId = `agent-${Date.now()}`;
    const newNode = {
      id: newId,
      type: 'agent',
      data: { label: `🤖 New Agent`, role: 'worker', model: $gatewayConfig.model || 'llama3.1' },
      position: { 
        x: 100 + Math.random() * 600, 
        y: 100 + Math.random() * 300 
      },
    };
    
    nodes = [...nodes, newNode];
    console.log('➕ Added agent:', newId, '- Total:', nodes.length);
    saveToLocalStorage();
    showToastMessage('✅ Agent added', 'success');
  }

  function addInput() {
    const newId = `input-${Date.now()}`;
    const newNode = {
      id: newId,
      type: 'input',
      data: { label: `📥 New Input`, role: 'input', model: 'llama3.1' },
      position: { 
        x: 50 + Math.random() * 200, 
        y: 100 + Math.random() * 300 
      },
    };
    
    nodes = [...nodes, newNode];
    console.log('➕ Added input:', newId, '- Total:', nodes.length);
    saveToLocalStorage();
    showToastMessage('✅ Input node added', 'success');
  }

  function addOutput() {
    const newId = `output-${Date.now()}`;
    const newNode = {
      id: newId,
      type: 'output',
      data: { label: `📤 New Output`, role: 'output', model: 'llama3.1' },
      position: { 
        x: 600 + Math.random() * 200, 
        y: 100 + Math.random() * 300 
      },
    };
    
    nodes = [...nodes, newNode];
    console.log('➕ Added output:', newId, '- Total:', nodes.length);
    saveToLocalStorage();
    showToastMessage('✅ Output node added', 'success');
  }

  function clearCanvas() {
    if (confirm('Clear canvas and reset to default mock data?')) {
      nodes = [...DEFAULT_MOCK_NODES];
      edges = [...DEFAULT_MOCK_EDGES];
      usingMockData = true;
      saveToLocalStorage();
      console.log('🗑️ Canvas cleared - reset to mock data');
      showToastMessage('✅ Canvas reset to default', 'success');
    }
  }

  // Handle node drag stop - update position and save
  function handleNodeDragStop(event: any) {
    console.log('🎯 Node drag stopped:', event.detail);
    // SvelteFlow automatically updates node positions in the nodes array
    saveToLocalStorage();
  }

  // Handle double-click on node to open editor
  function handleNodeDoubleClick(event: any) {
    const node = event.detail?.node || event.detail;
    if (!node) return;
    
    editingNode = node;
    editNodeLabel = node.data?.label || '';
    editNodeRole = node.data?.role || 'worker';
    editNodeModel = node.data?.model || $gatewayConfig.model || 'llama3.1';
    showNodeEditor = true;
  }

  // Save node edits
  function saveNodeEdits() {
    if (!editingNode) return;
    
    nodes = nodes.map(n => 
      n.id === editingNode.id 
        ? { ...n, data: { ...n.data, label: editNodeLabel, role: editNodeRole, model: editNodeModel } }
        : n
    );
    
    showNodeEditor = false;
    editingNode = null;
    saveToLocalStorage();
    showToastMessage('Node updated', 'success');
  }

  // Delete a specific node by id
  function deleteNode(nodeId: string) {
    nodes = nodes.filter(n => n.id !== nodeId);
    edges = edges.filter(e => e.source !== nodeId && e.target !== nodeId);
    showNodeEditor = false;
    editingNode = null;
    saveToLocalStorage();
    showToastMessage('Node deleted', 'success');
  }

  // Handle new connection - add edge
  function handleConnect(event: any) {
    const connection = event.detail;
    console.log('🔗 New connection:', connection);
    
    const newEdge = {
      id: `e-${connection.source}-${connection.target}`,
      source: connection.source,
      target: connection.target,
      type: 'smoothstep'
    };
    
    edges = [...edges, newEdge];
    saveToLocalStorage();
    showToastMessage('✅ Connection created', 'success');
  }

  // Handle node deletion
  function handleNodesDelete(event: any) {
    console.log('🗑️ Nodes deleted:', event.detail);
    saveToLocalStorage();
    showToastMessage('✅ Node deleted', 'success');
  }

  // Handle edge deletion
  function handleEdgesDelete(event: any) {
    console.log('🗑️ Edges deleted:', event.detail);
    saveToLocalStorage();
    showToastMessage('✅ Connection deleted', 'success');
  }

  function generateConfig() {
    return {
      agents: {
        defaults: {
          model: {
            primary: $gatewayConfig.provider === 'ollama' 
              ? `ollama/${$gatewayConfig.model}` 
              : `${$gatewayConfig.provider}/${$gatewayConfig.model}`
          },
          temperature: 0.7
        },
        swarm: nodes.map(node => ({
          id: node.id,
          name: node.data.label,
          role: node.data.role || 'worker',
          model: node.data.model || $gatewayConfig.model || 'llama3.1',
          position: {
            x: node.position.x,
            y: node.position.y
          }
        })),
        connections: edges.map(edge => ({
          from: edge.source,
          to: edge.target,
          type: 'delegate'
        }))
      },
      gateway: {
        port: 3333,
        host: '127.0.0.1',
        require_pairing: true
      }
    };
  }

  function exportConfig() {
    showExportModal = true;
  }

  // Add agent from library with preset role
  function addFromLibrary(preset: { label: string; role: string; icon: string }) {
    const newId = `${preset.role}-${Date.now()}`;
    const typeMap: Record<string, string> = { input: 'input', output: 'output' };
    const nodeType = typeMap[preset.role] || 'agent';
    
    const newNode = {
      id: newId,
      type: nodeType,
      data: { label: `${preset.icon} ${preset.label}`, role: preset.role, model: $gatewayConfig.model || 'llama3.1' },
      position: { 
        x: 100 + Math.random() * 500, 
        y: 100 + Math.random() * 300 
      },
    };
    
    nodes = [...nodes, newNode];
    saveToLocalStorage();
    showToastMessage(`Added ${preset.label}`, 'success');
  }

  // Run swarm execution - chains messages through connected agents
  async function runSwarm() {
    if (running) return;
    running = true;
    showRunPanel = true;
    
    // Build execution order from edges (topological sort)
    const inputNodes = nodes.filter(n => n.type === 'input' || n.data?.role === 'input');
    const outputNodes = nodes.filter(n => n.type === 'output' || n.data?.role === 'output');
    
    if (inputNodes.length === 0) {
      showToastMessage('No input node found. Add an input node to start the swarm.', 'error');
      running = false;
      return;
    }
    
    // Initialize run log
    runLog = nodes.map(n => ({
      nodeId: n.id,
      label: n.data?.label || n.id,
      status: 'pending'
    }));
    
    const gatewayUrl = $gatewayConfig.url || 'http://127.0.0.1:3000';
    const model = $gatewayConfig.model || 'llama3.1';
    const initialMessage = 'Hello, I need help with a task.';
    
    // Per-node output tracking so branching/convergent graphs get correct inputs
    const nodeOutputs = new Map<string, string>();
    
    // Kahn's algorithm: compute in-degrees and process nodes in topological order
    const inDegree = new Map<string, number>();
    for (const n of nodes) {
      inDegree.set(n.id, 0);
    }
    for (const e of edges) {
      inDegree.set(e.target, (inDegree.get(e.target) || 0) + 1);
    }
    
    // Initialize queue with nodes that have in-degree 0 (no parents)
    const queue: string[] = [];
    for (const n of nodes) {
      if ((inDegree.get(n.id) || 0) === 0) {
        queue.push(n.id);
      }
    }
    
    while (queue.length > 0) {
      const nodeId = queue.shift();
      if (!nodeId) continue;
      
      const node = nodes.find(n => n.id === nodeId);
      if (!node) continue;
      
      // Determine input: combine outputs from all parent nodes, or use initial message
      const parentEdges = edges.filter(e => e.target === nodeId);
      let nodeInput: string;
      if (parentEdges.length === 0) {
        nodeInput = initialMessage;
      } else {
        const parentOutputs = parentEdges
          .map(e => nodeOutputs.get(e.source))
          .filter((o): o is string => o !== undefined);
        nodeInput = parentOutputs.length > 0 ? parentOutputs.join('\n\n') : initialMessage;
      }
      
      // Update status to running
      runLog = runLog.map(r => r.nodeId === nodeId ? { ...r, status: 'running' } : r);
      
      try {
        // Send message through gateway for agent nodes
        if (node.type === 'agent' || node.data?.role === 'coordinator' || node.data?.role === 'worker' || node.data?.role === 'planner' || node.data?.role === 'researcher' || node.data?.role === 'coder' || node.data?.role === 'critic') {
          const systemPrompt = `You are ${node.data?.label || 'an AI agent'} with role: ${node.data?.role || 'worker'}. Process the input and respond concisely.`;
          
          const response = await fetch(`${gatewayUrl}/v1/chat/completions`, {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify({
              model: node.data?.model || model,
              messages: [
                { role: 'system', content: systemPrompt },
                { role: 'user', content: nodeInput }
              ]
            }),
            signal: AbortSignal.timeout(30000)
          });
          
          if (response.ok) {
            const data = await response.json();
            const reply = data.choices?.[0]?.message?.content || data.choices?.[0]?.delta?.content || 'No response';
            nodeOutputs.set(nodeId, reply);
            runLog = runLog.map(r => r.nodeId === nodeId ? { ...r, status: 'done', message: reply.substring(0, 100) } : r);
          } else {
            nodeOutputs.set(nodeId, nodeInput);
            runLog = runLog.map(r => r.nodeId === nodeId ? { ...r, status: 'error', message: `HTTP ${response.status}` } : r);
          }
        } else {
          // Input/output nodes just pass through
          nodeOutputs.set(nodeId, nodeInput);
          runLog = runLog.map(r => r.nodeId === nodeId ? { ...r, status: 'done', message: node.type === 'input' ? 'Input received' : `Output: ${nodeInput.substring(0, 80)}` } : r);
        }
      } catch (error) {
        const msg = error instanceof Error ? error.message : String(error);
        nodeOutputs.set(nodeId, nodeInput);
        runLog = runLog.map(r => r.nodeId === nodeId ? { ...r, status: 'error', message: msg } : r);
      }
      
      // Decrement in-degree of downstream nodes; enqueue when all parents are done
      const downstream = edges.filter(e => e.source === nodeId).map(e => e.target);
      for (const next of downstream) {
        const newDegree = (inDegree.get(next) || 1) - 1;
        inDegree.set(next, newDegree);
        if (newDegree === 0) {
          queue.push(next);
        }
      }
    }
    
    running = false;
    showToastMessage('Swarm execution complete', 'success');
  }

  // Deploy swarm config to gateway
  async function deployToGateway() {
    deploying = true;
    const config = generateConfig();
    
    try {
      const api = new GatewayAPI($gatewayConfig.url, $gatewayConfig.bearerToken);
      const result = await api.applySwarmConfig(config);
      
      if (result.success) {
        showToastMessage('Swarm config deployed to gateway', 'success');
      } else {
        // Gateway doesn't support /config/swarm yet — auto-download instead
        showToastMessage('Gateway endpoint not available yet. Downloading config file...', 'error');
        // Auto-trigger download as fallback
        const content = JSON.stringify(config, null, 2);
        const blob = new Blob([content], { type: 'application/json' });
        const url = URL.createObjectURL(blob);
        const a = document.createElement('a');
        a.href = url;
        a.download = 'nullclaw-swarm-config.json';
        document.body.appendChild(a);
        a.click();
        document.body.removeChild(a);
        URL.revokeObjectURL(url);
      }
    } catch (error) {
      const msg = error instanceof Error ? error.message : String(error);
      showToastMessage(`Deploy failed: ${msg}`, 'error');
    } finally {
      deploying = false;
    }
  }

  function downloadConfig() {
    exporting = true;
    
    try {
      const config = generateConfig();
      const content = exportFormat === 'json' 
        ? JSON.stringify(config, null, 2)
        : jsonToYaml(config);
      
      const filename = `nullclaw-swarm-config.${exportFormat}`;
      const mimeType = exportFormat === 'json' ? 'application/json' : 'text/yaml';
      
      const blob = new Blob([content], { type: mimeType });
      const url = URL.createObjectURL(blob);
      const a = document.createElement('a');
      a.href = url;
      a.download = filename;
      document.body.appendChild(a);
      a.click();
      document.body.removeChild(a);
      URL.revokeObjectURL(url);

      showToastMessage(`✅ Config exported as ${filename}`, 'success');
      showExportModal = false;
    } catch (error) {
      const errorMsg = error instanceof Error ? error.message : String(error);
      showToastMessage(`❌ Export failed: ${errorMsg}`, 'error');
    } finally {
      exporting = false;
    }
  }

  function jsonToYaml(obj: any, indent = 0): string {
    const spaces = '  '.repeat(indent);
    let yaml = '';

    for (const [key, value] of Object.entries(obj)) {
      if (value === null || value === undefined) {
        yaml += `${spaces}${key}: null\n`;
      } else if (typeof value === 'object' && !Array.isArray(value)) {
        yaml += `${spaces}${key}:\n${jsonToYaml(value, indent + 1)}`;
      } else if (Array.isArray(value)) {
        yaml += `${spaces}${key}:\n`;
        value.forEach(item => {
          if (typeof item === 'object') {
            yaml += `${spaces}  -\n${jsonToYaml(item, indent + 2).replace(/^/gm, '  ')}`;
          } else {
            yaml += `${spaces}  - ${item}\n`;
          }
        });
      } else if (typeof value === 'string') {
        yaml += `${spaces}${key}: "${value}"\n`;
      } else {
        yaml += `${spaces}${key}: ${value}\n`;
      }
    }

    return yaml;
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
      <p class="text-gray-400">Initializing...</p>
    </div>
  </div>
{:else if !loaded && !forceLoaded}
  <div class="min-h-screen flex items-center justify-center">
    <div class="text-center">
      <div class="relative inline-block">
        <div class="text-6xl mb-4">🔄</div>
        <div class="absolute inset-0 animate-spin">
          <div class="text-6xl opacity-30">⚙️</div>
        </div>
      </div>
      <p class="text-gray-400 font-semibold">Loading Swarm Canvas...</p>
      {#if fetchingFromGateway}
        <p class="text-sm text-blue-400 mt-2 animate-pulse">Fetching from gateway...</p>
      {:else}
        <p class="text-xs text-gray-500 mt-2">Loading components...</p>
      {/if}
    </div>
  </div>
{:else}
  <div class="min-h-screen flex flex-col">
    <!-- Header -->
    <header class="glass border-b border-nebula-primary/20 p-4">
      <div class="max-w-7xl mx-auto flex items-center justify-between">
        <div class="flex items-center gap-4">
          <a href="/" class="glass px-4 py-2 rounded-lg hover:bg-nebula-primary/20 transition-all flex items-center gap-2">
            <span class="text-xl">←</span>
            <span>Back</span>
          </a>
          <h1 class="text-2xl font-bold">Swarm Forge</h1>
        </div>
        <div class="flex gap-2">
          <button
            on:click={addInput}
            class="px-4 py-2 glass hover:bg-green-500/20 rounded-lg border border-green-500/30 hover:border-green-500/60 transition-all"
          >
            📥 Add Input
          </button>
          <button
            on:click={addAgent}
            class="px-4 py-2 bg-nebula-primary hover:bg-nebula-primaryLight rounded-lg font-semibold"
          >
            🤖 Add Agent
          </button>
          <button
            on:click={addOutput}
            class="px-4 py-2 glass hover:bg-blue-500/20 rounded-lg border border-blue-500/30 hover:border-blue-500/60 transition-all"
          >
            📤 Add Output
          </button>
          <button 
            on:click={clearCanvas}
            class="px-4 py-2 glass hover:bg-red-500/20 rounded-lg text-red-400 border border-red-500/30 hover:border-red-500/60 transition-all"
          >
            🗑️ Clear
          </button>
          <button 
            on:click={runSwarm}
            disabled={running}
            class="px-4 py-2 bg-green-600 hover:bg-green-500 disabled:opacity-50 rounded-lg font-semibold transition-all"
          >
            {running ? '⏳ Running...' : '▶ Run Swarm'}
          </button>
          <button 
            on:click={deployToGateway}
            disabled={deploying}
            class="px-4 py-2 glass hover:bg-nebula-accent/20 rounded-lg border border-nebula-accent/30 hover:border-nebula-accent/60 transition-all"
          >
            {deploying ? '⏳ Deploying...' : '🚀 Deploy'}
          </button>
          <button 
            on:click={exportConfig}
            class="px-4 py-2 glass hover:bg-nebula-card rounded-lg border border-nebula-primary/30 hover:border-nebula-primary/60 transition-all"
          >
            💾 Export
          </button>
        </div>
      </div>
    </header>

    <!-- Status Banner -->
    {#if usingMockData}
      <div class="bg-blue-500/10 border-b border-blue-500/30 px-4 py-2">
        <div class="max-w-7xl mx-auto text-sm text-blue-400 flex items-center justify-between">
          <span>ℹ️ Starting fresh – build your swarm below</span>
          <span class="text-xs">Fully interactive - changes auto-saved</span>
        </div>
      </div>
    {:else}
      <div class="bg-green-500/10 border-b border-green-500/30 px-4 py-2">
        <div class="max-w-7xl mx-auto text-sm text-green-400 flex items-center justify-between">
          <span>✅ Swarm loaded</span>
          <span class="text-xs">{nodes.length} nodes, {edges.length} connections</span>
        </div>
      </div>
    {/if}

    <!-- Canvas -->
    <div class="flex-1 relative min-h-[600px]">
      {#if SvelteFlow && Background && Controls && nodes && edges && nodes.length > 0}
        <div class="absolute inset-0 glass">
          {#key `${nodes.length}-${edges.length}`}
            {@const flowProps = {
              nodes,
              edges,
              fitView: true,
              nodesDraggable: true,
              nodesConnectable: true,
              elementsSelectable: true
            }}
            <SvelteFlow 
              {nodes}
              {edges}
              {nodeTypes}
              fitView={true}
              nodesDraggable={true}
              nodesConnectable={true}
              elementsSelectable={true}
              on:nodedragstop={handleNodeDragStop}
              on:connect={handleConnect}
              on:nodesdelete={handleNodesDelete}
              on:edgesdelete={handleEdgesDelete}
              on:nodedoubleclick={handleNodeDoubleClick}
            >
              <Background />
              <Controls />
            </SvelteFlow>
          {/key}
        </div>
      {:else if !SvelteFlow && loaded}
        <div class="absolute inset-0 glass flex items-center justify-center">
          <div class="text-center text-gray-400">
            <div class="text-6xl mb-4">📊</div>
            <h2 class="text-2xl font-bold mb-2">Swarm Canvas Ready</h2>
            <p class="mb-4">Visual canvas unavailable - using list mode</p>
            {#if loadError}
              <div class="bg-red-500/10 border border-red-500/30 rounded-lg p-4 max-w-md mx-auto mb-4">
                <p class="text-sm text-red-400">{loadError}</p>
              </div>
            {/if}
            <div class="text-left max-w-md mx-auto glass p-4 rounded-lg">
              <h3 class="font-bold mb-2">Current Agents ({nodes.length}):</h3>
              {#each nodes as node}
                <div class="p-2 bg-nebula-primary/10 rounded mb-2">
                  <div class="font-semibold">{node.data.label}</div>
                  <div class="text-xs text-gray-400">{node.data.role}</div>
                </div>
              {/each}
            </div>
          </div>
        </div>
      {:else}
        <div class="absolute inset-0 glass flex items-center justify-center">
          <div class="text-center text-gray-400">
            <div class="text-4xl mb-4 animate-spin">⏳</div>
            <p>Loading canvas components...</p>
          </div>
        </div>
      {/if}
    </div>

    <!-- Sidebar -->
    <div class="absolute right-4 top-24 w-64 glass p-4 rounded-xl">
      <h3 class="font-bold mb-4">Agent Library</h3>
      <p class="text-xs text-gray-400 mb-3">Click to add to canvas</p>
      <div class="space-y-2">
        <button
          on:click={() => addFromLibrary({ label: 'Worker Agent', role: 'worker', icon: '🤖' })}
          class="w-full text-left p-3 bg-nebula-primary/10 rounded-lg cursor-pointer hover:bg-nebula-primary/20 transition-all"
        >
          <div class="font-semibold">🤖 Worker Agent</div>
          <div class="text-xs text-gray-400">Execute tasks</div>
        </button>
        <button
          on:click={() => addFromLibrary({ label: 'Planner Agent', role: 'planner', icon: '🧠' })}
          class="w-full text-left p-3 bg-nebula-accent/10 rounded-lg cursor-pointer hover:bg-nebula-accent/20 transition-all"
        >
          <div class="font-semibold">🧠 Planner Agent</div>
          <div class="text-xs text-gray-400">Strategy & planning</div>
        </button>
        <button
          on:click={() => addFromLibrary({ label: 'Researcher Agent', role: 'researcher', icon: '🔍' })}
          class="w-full text-left p-3 bg-nebula-secondary/10 rounded-lg cursor-pointer hover:bg-nebula-secondary/20 transition-all"
        >
          <div class="font-semibold">🔍 Researcher Agent</div>
          <div class="text-xs text-gray-400">Gather information</div>
        </button>
        <button
          on:click={() => addFromLibrary({ label: 'Coder Agent', role: 'coder', icon: '💻' })}
          class="w-full text-left p-3 bg-blue-500/10 rounded-lg cursor-pointer hover:bg-blue-500/20 transition-all"
        >
          <div class="font-semibold">💻 Coder Agent</div>
          <div class="text-xs text-gray-400">Write & review code</div>
        </button>
        <button
          on:click={() => addFromLibrary({ label: 'Critic Agent', role: 'critic', icon: '🔬' })}
          class="w-full text-left p-3 bg-yellow-500/10 rounded-lg cursor-pointer hover:bg-yellow-500/20 transition-all"
        >
          <div class="font-semibold">🔬 Critic Agent</div>
          <div class="text-xs text-gray-400">Evaluate & improve output</div>
        </button>
      </div>
    </div>

    <!-- Run Panel (execution log) -->
    {#if showRunPanel && runLog.length > 0}
      <div class="absolute left-4 top-24 w-72 glass p-4 rounded-xl max-h-[60vh] overflow-y-auto">
        <div class="flex items-center justify-between mb-3">
          <h3 class="font-bold">Execution Log</h3>
          <button on:click={() => showRunPanel = false} class="text-gray-400 hover:text-white">&times;</button>
        </div>
        <div class="space-y-2">
          {#each runLog as entry}
            <div class={`p-2 rounded-lg border text-sm ${
              entry.status === 'running' ? 'border-yellow-500/50 bg-yellow-500/10' :
              entry.status === 'done' ? 'border-green-500/50 bg-green-500/10' :
              entry.status === 'error' ? 'border-red-500/50 bg-red-500/10' :
              'border-gray-700 bg-gray-800/50'
            }`}>
              <div class="flex items-center gap-2">
                <span class="text-xs">
                  {entry.status === 'running' ? '⏳' : entry.status === 'done' ? '✅' : entry.status === 'error' ? '❌' : '⏸️'}
                </span>
                <span class="font-semibold text-xs">{entry.label}</span>
              </div>
              {#if entry.message}
                <p class="text-xs text-gray-400 mt-1 line-clamp-2">{entry.message}</p>
              {/if}
            </div>
          {/each}
        </div>
      </div>
    {/if}
  </div>

  <!-- Node Editor Modal -->
  {#if showNodeEditor && editingNode}
    <div class="fixed inset-0 bg-black/80 flex items-center justify-center p-8 z-50">
      <div class="glass max-w-md w-full p-6 rounded-xl">
        <h2 class="text-xl font-bold mb-4">Edit Node</h2>
        
        <div class="space-y-4">
          <div>
            <label class="block text-sm text-gray-400 mb-1">Label</label>
            <input
              type="text"
              bind:value={editNodeLabel}
              class="w-full glass px-4 py-2 rounded-lg focus:outline-none focus:ring-2 focus:ring-nebula-primary"
              placeholder="Node label"
            />
          </div>
          
          <div>
            <label class="block text-sm text-gray-400 mb-1">Role</label>
            <select
              bind:value={editNodeRole}
              class="w-full glass px-4 py-2 rounded-lg focus:outline-none focus:ring-2 focus:ring-nebula-primary bg-nebula-bg"
            >
              <option value="input">Input</option>
              <option value="output">Output</option>
              <option value="coordinator">Coordinator</option>
              <option value="worker">Worker</option>
              <option value="planner">Planner</option>
              <option value="researcher">Researcher</option>
              <option value="coder">Coder</option>
              <option value="critic">Critic</option>
            </select>
          </div>
          
          <div>
            <label class="block text-sm text-gray-400 mb-1">Model</label>
            <input
              type="text"
              bind:value={editNodeModel}
              class="w-full glass px-4 py-2 rounded-lg focus:outline-none focus:ring-2 focus:ring-nebula-primary"
              placeholder="e.g. llama3.1, claude-sonnet-4, gpt-4o"
            />
          </div>
          
          <div class="text-xs text-gray-500">
            Node ID: {editingNode.id} &middot; Type: {editingNode.type}
          </div>
        </div>
        
        <div class="flex gap-3 mt-6">
          <button
            on:click={() => { showNodeEditor = false; editingNode = null; }}
            class="flex-1 px-4 py-3 glass hover:bg-nebula-card rounded-lg"
          >
            Cancel
          </button>
          <button
            on:click={() => deleteNode(editingNode.id)}
            class="px-4 py-3 bg-red-600 hover:bg-red-500 rounded-lg font-semibold"
          >
            Delete
          </button>
          <button
            on:click={saveNodeEdits}
            class="flex-1 px-4 py-3 bg-nebula-primary hover:bg-nebula-primaryLight rounded-lg font-semibold"
          >
            Save
          </button>
        </div>
      </div>
    </div>
  {/if}

  <!-- Export Modal -->
  {#if showExportModal}
    <div class="fixed inset-0 bg-black/80 flex items-center justify-center p-8 z-50">
      <div class="glass max-w-2xl w-full p-8">
        <h2 class="text-2xl font-bold mb-4">Export Swarm Configuration</h2>
        
        <p class="text-gray-400 mb-6">
          Export your swarm configuration as a NullClaw-compatible config file.
        </p>

        <!-- Format Selection -->
        <div class="mb-6">
          <label class="block text-sm text-gray-400 mb-2">Export Format</label>
          <div class="flex gap-4">
            <label class="flex items-center gap-2 cursor-pointer">
              <input
                type="radio"
                bind:group={exportFormat}
                value="json"
                class="w-4 h-4"
              />
              <span>JSON</span>
            </label>
            <label class="flex items-center gap-2 cursor-pointer">
              <input
                type="radio"
                bind:group={exportFormat}
                value="yaml"
                class="w-4 h-4"
              />
              <span>YAML</span>
            </label>
          </div>
        </div>

        <!-- Config Preview -->
        <div class="mb-6">
          <label class="block text-sm text-gray-400 mb-2">Preview</label>
          <div class="bg-nebula-bg/50 border border-nebula-primary/20 rounded-lg p-4 max-h-64 overflow-y-auto">
            <pre class="text-xs text-gray-300 font-mono">{exportFormat === 'json' 
              ? JSON.stringify(generateConfig(), null, 2) 
              : jsonToYaml(generateConfig())}</pre>
          </div>
        </div>

        <!-- Stats -->
        <div class="grid grid-cols-2 gap-4 mb-6">
          <div class="glass p-4 rounded-lg">
            <div class="text-2xl font-bold text-nebula-primary">{nodes.length}</div>
            <div class="text-sm text-gray-400">Agents</div>
          </div>
          <div class="glass p-4 rounded-lg">
            <div class="text-2xl font-bold text-nebula-accent">{edges.length}</div>
            <div class="text-sm text-gray-400">Connections</div>
          </div>
        </div>

        <!-- Actions -->
        <div class="flex gap-3">
          <button
            on:click={() => showExportModal = false}
            class="flex-1 px-4 py-3 glass hover:bg-nebula-card rounded-lg"
            disabled={exporting}
          >
            Cancel
          </button>
          <button
            on:click={downloadConfig}
            disabled={exporting}
            class="flex-1 px-4 py-3 bg-nebula-primary hover:bg-nebula-primaryLight disabled:opacity-50 rounded-lg font-semibold"
          >
            {exporting ? 'Exporting...' : 'Download File'}
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
  :global(.svelte-flow) {
    background: transparent !important;
  }
  
  :global(.svelte-flow__node) {
    background: rgba(17, 17, 24, 0.9) !important;
    border: 2px solid rgba(124, 58, 237, 0.3) !important;
    border-radius: 12px !important;
    color: #e0e0ff !important;
    padding: 12px !important;
  }

  :global(.svelte-flow__node:hover) {
    border-color: rgba(124, 58, 237, 0.8) !important;
    box-shadow: 0 0 20px rgba(124, 58, 237, 0.5) !important;
  }

  :global(.svelte-flow__edge-path) {
    stroke: rgba(124, 58, 237, 0.6) !important;
    stroke-width: 2px !important;
  }

  :global(.svelte-flow__edge-text) {
    fill: #a78bfa !important;
  }

  /* Move zoom controls to bottom-center so they don't overlap canvas nodes */
  :global(.svelte-flow__controls) {
    left: 50% !important;
    bottom: 12px !important;
    transform: translateX(-50%) !important;
    display: flex !important;
    flex-direction: row !important;
    gap: 4px !important;
    background: rgba(17, 17, 24, 0.9) !important;
    border: 1px solid rgba(124, 58, 237, 0.3) !important;
    border-radius: 8px !important;
    padding: 4px !important;
  }

  :global(.svelte-flow__controls button) {
    background: transparent !important;
    border: none !important;
    color: #a78bfa !important;
    fill: #a78bfa !important;
  }

  :global(.svelte-flow__controls button:hover) {
    background: rgba(124, 58, 237, 0.2) !important;
    border-radius: 4px !important;
  }

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
