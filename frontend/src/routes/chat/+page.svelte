<script lang="ts">
  import { onMount, onDestroy } from 'svelte';
  import { gatewayConfig } from '$lib/stores/gateway';
  import { memories, type Memory, getActiveMemoryMessages, toggleMemoryActive } from '$lib/stores/memories';

  let mounted = $state(false);
  let messages: Array<{ role: 'user' | 'assistant'; content: string; timestamp: Date }> = $state([]);
  let inputMessage = $state('');
  let sending = $state(false);
  let polling = $state(false);
  let pollingInterval: number | null = $state(null);
  let sessionId = $state('current-session');
  let chatMode: 'async' | 'direct' = $state('direct'); // 'async' for gateway webhook, 'direct' for Ollama
  let streaming = $state(false);
  let currentStreamAssistantMessage: { role: 'assistant'; content: string; timestamp: Date } | null = $state(null);
  let showMemoryPanel = $state(false);

  onMount(async () => {
    mounted = true;
    loadMessages();
    
    // Load or create session ID
    if (typeof localStorage !== 'undefined') {
      const saved = localStorage.getItem('chat_session_id');
      if (saved) {
        sessionId = saved;
      } else {
        sessionId = `session-${Date.now()}`;
        localStorage.setItem('chat_session_id', sessionId);
      }
      
      // Load chat mode from localStorage
      const savedMode = localStorage.getItem('chat_mode');
      if (savedMode === 'async' || savedMode === 'direct') {
        chatMode = savedMode;
      }
    }
  });

  onDestroy(() => {
    // Clean up polling interval on component destroy
    if (pollingInterval) {
      clearInterval(pollingInterval);
      pollingInterval = null;
    }
    // Reset streaming state
    streaming = false;
    currentStreamAssistantMessage = null;
  });

  function loadMessages() {
    if (typeof localStorage === 'undefined') return;
    const saved = localStorage.getItem('chat_messages');
    if (saved) {
      try {
        const parsed = JSON.parse(saved);
        messages = parsed.map((m: any) => ({
          ...m,
          timestamp: new Date(m.timestamp)
        }));
      } catch (error) {
        console.error('Failed to load messages:', error);
      }
    }
  }

  function saveMessages() {
    if (typeof localStorage === 'undefined') return;
    localStorage.setItem('chat_messages', JSON.stringify(messages));
  }

  async function sendMessage() {
    if (!inputMessage.trim() || sending || streaming) return;
    
    const userMessage = inputMessage.trim();
    inputMessage = '';
    
    // Add user message
    messages = [...messages, {
      role: 'user',
      content: userMessage,
      timestamp: new Date()
    }];
    saveMessages();

    sending = true;

    try {
      if (chatMode === 'async') {
        // Async mode: Use gateway webhook with polling
        if (!$gatewayConfig.connected) {
          alert('Gateway is not connected. Please check Settings.');
          return;
        }
        
        if (!$gatewayConfig.paired) {
          alert('Please pair with gateway first in Settings.');
          return;
        }

        console.log('🚀 Sending to gateway /webhook (async mode):', $gatewayConfig.url);
        console.log('📝 Message:', userMessage);
        console.log('🔑 Session ID:', sessionId);
        
        // POST to /webhook endpoint via CORS proxy
        const response = await fetch(`${$gatewayConfig.url}/webhook`, {
          method: 'POST',
          headers: {
            'Content-Type': 'application/json',
            'Authorization': `Bearer ${$gatewayConfig.bearerToken}`
          },
          body: JSON.stringify({
            session: sessionId,
            message: userMessage,
            sender: 'web-user'
          })
        });

        if (!response.ok) {
          throw new Error(`Gateway error: ${response.status} ${response.statusText}`);
        }

        const data = await response.json();
        console.log('✅ Webhook response:', data);
        
        // Check if we got {"status":"received"} or similar
        if (data.status === 'received' || data.status === 'ok') {
          // Start polling for the AI reply using direct WSL gateway URL
          startPolling();
        } else if (data.response) {
          // If we got an immediate reply in the response field, add it
          messages = [...messages, {
            role: 'assistant',
            content: data.response,
            timestamp: new Date()
          }];
          saveMessages();
        } else if (data.reply || data.message) {
          // Fallback for other response formats
          messages = [...messages, {
            role: 'assistant',
            content: data.reply || data.message,
            timestamp: new Date()
          }];
          saveMessages();
        }
      } else {
        // Direct mode: Stream through NullClaw gateway
        const gatewayUrl = $gatewayConfig.url || 'http://127.0.0.1:3000';
        const model = $gatewayConfig.model || 'llama3.1';
        console.log(`Sending to ${gatewayUrl}/v1/chat/completions (streaming, model: ${model})`);
        
        streaming = true;
        
        // Create assistant message placeholder for streaming
        currentStreamAssistantMessage = {
          role: 'assistant',
          content: '',
          timestamp: new Date()
        };
        
        // Add placeholder to messages for streaming display
        messages = [...messages, currentStreamAssistantMessage];
        
        try {
            // Build messages with active memory context
            const memoryMessages = getActiveMemoryMessages($memories);
            const chatHistory = messages.slice(0, -2).map(m => ({ role: m.role, content: m.content }));
          
            const response = await fetch(`${gatewayUrl}/v1/chat/completions`, {
              method: 'POST',
              headers: {
                'Content-Type': 'application/json'
              },
              body: JSON.stringify({
                model,
                messages: [
                  ...memoryMessages,
                  ...chatHistory,
                  { role: 'user', content: userMessage }
                ],
                stream: true
              })
            });

          if (!response.ok) {
            if (response.status === 0 || response.status === 404) {
              throw new Error('NullClaw gateway not running. Run `nullclaw serve` first.');
            }
            throw new Error(`Gateway error: ${response.status} ${response.statusText}`);
          }

          // Stream the response
          const reader = response.body?.getReader();
          const decoder = new TextDecoder();
          let fullResponse = '';

          if (reader) {
            while (true) {
              const { done, value } = await reader.read();
              if (done) break;

              const chunk = decoder.decode(value);
              const lines = chunk.split('\n').filter(line => line.trim() !== '');

              for (const line of lines) {
                if (line.startsWith('data: ')) {
                  const data = line.slice(6);
                  if (data === '[DONE]') continue;

                  try {
                    const parsed = JSON.parse(data);
                    const content = parsed.choices?.[0]?.delta?.content || '';
                    
                    if (content) {
                      fullResponse += content;
                      
                      // Update the streaming message
                      if (currentStreamAssistantMessage) {
                        currentStreamAssistantMessage.content = fullResponse;
                        
                        // Update the messages array to trigger UI update
                        messages = [...messages.slice(0, -1), currentStreamAssistantMessage];
                      }
                    }
                  } catch (e) {
                    console.error('Error parsing stream chunk:', e, 'Data:', data);
                  }
                }
              }
            }
          }

          // Finalize the message
          if (currentStreamAssistantMessage) {
            currentStreamAssistantMessage.content = fullResponse;
            saveMessages();
          }
          
        } catch (streamError) {
          const errorMsg = streamError instanceof Error ? streamError.message : String(streamError);
          console.error('❌ Stream error:', errorMsg);
          
          // Update error message with helpful instructions
          let errorContent = `Error: ${errorMsg}`;
          if (errorMsg.includes('gateway not running') || errorMsg.includes('Failed to fetch')) {
            errorContent = `NullClaw gateway not reachable. Please:\n1. Run \`nullclaw serve\` in terminal\n2. Make sure Ollama is running: \`ollama serve\`\n3. Refresh this page`;
          }
          
          // Update error message
          if (currentStreamAssistantMessage) {
            currentStreamAssistantMessage.content = errorContent;
            saveMessages();
          }
        } finally {
          streaming = false;
          currentStreamAssistantMessage = null;
        }
      }
      
    } catch (error) {
      const errorMsg = error instanceof Error ? error.message : String(error);
      console.error('❌ Send error:', errorMsg);
      
      messages = [...messages, {
        role: 'assistant',
        content: `Error: ${errorMsg}`,
        timestamp: new Date()
      }];
      saveMessages();
    } finally {
      sending = false;
    }
  }

  function startPolling() {
    console.log('🔄 Starting polling for replies...');
    polling = true;
    
    let pollCount = 0;
    const maxPolls = 15; // 15 polls × 2 seconds = 30 seconds max
    
    // Use the configured gateway URL for polling (auto-discovered or user-configured)
    const gatewayDirectUrl = $gatewayConfig.url;
    
    pollingInterval = window.setInterval(async () => {
      pollCount++;
      console.log(`📡 Poll attempt ${pollCount}/${maxPolls} to ${gatewayDirectUrl}/session/${sessionId}/messages`);
      
      try {
        // Try to fetch messages from session endpoint using direct WSL URL
        const response = await fetch(`${gatewayDirectUrl}/session/${sessionId}/messages`, {
          headers: {
            'Authorization': `Bearer ${$gatewayConfig.bearerToken}`
          }
        });

        if (response.ok) {
          const data = await response.json();
          console.log('📨 Polling response:', data);
          
          // Check if we got new messages
          if (data.messages && Array.isArray(data.messages)) {
            const newMessages = data.messages.filter((m: any) => 
              m.role === 'assistant' && 
              !messages.some(existing => existing.content === m.content)
            );
            
            if (newMessages.length > 0) {
              console.log('✅ Found new assistant messages:', newMessages.length);
              
              // Add new messages to chat
              messages = [...messages, ...newMessages.map((m: any) => ({
                role: 'assistant' as const,
                content: m.content || m.message,
                timestamp: new Date()
              }))];
              saveMessages();
              
              // Stop polling - we got a reply
              stopPolling();
              return;
            }
          }
        } else if (response.status === 404) {
          console.warn('⚠️ Session endpoint not found (404) - endpoint may not be implemented yet');
          // Show toast message as requested by user
          if (pollCount === 1) { // Only show once
            messages = [...messages, {
              role: 'assistant',
              content: '⚠️ No reply endpoint yet – check gateway logs\n\nThe /session/{id}/messages endpoint is not implemented in the gateway yet. The gateway may be processing your message asynchronously, but there\'s no polling endpoint to fetch the reply.\n\nCheck the gateway terminal for "Generated response" messages.',
              timestamp: new Date()
            }];
            saveMessages();
            stopPolling();
            return;
          }
        } else {
          console.warn(`⚠️ Polling failed with status ${response.status}`);
        }
        
      } catch (error) {
        console.error('❌ Polling error:', error);
        
        // If it's a network error (CORS, etc.), show helpful message
        if (error instanceof TypeError && error.message.includes('Failed to fetch')) {
          console.log('🌐 Network error - session endpoint may not exist or CORS issue');
        }
      }
      
      // Stop after max attempts
      if (pollCount >= maxPolls) {
        console.warn('⏱️ Polling timeout - no reply after 30 seconds');
        stopPolling();
        
        // Show timeout message with helpful debugging info
        messages = [...messages, {
          role: 'assistant',
          content: `⏱️ No reply received after 30 seconds.\n\nDebugging info:\n• Session ID: ${sessionId}\n• Polling URL: ${gatewayDirectUrl}/session/${sessionId}/messages\n• Gateway logs: Check Terminal 8 for "Generated response" messages\n\nPossible issues:\n1. Session endpoint not implemented in gateway\n2. AI provider is slow/unavailable\n3. Gateway is still processing the request\n\nTry checking the gateway terminal for processing logs.`,
          timestamp: new Date()
        }];
        saveMessages();
      }
    }, 2000); // Poll every 2 seconds
  }

  function stopPolling() {
    if (pollingInterval) {
      clearInterval(pollingInterval);
      pollingInterval = null;
    }
    polling = false;
    console.log('🛑 Polling stopped');
  }

  function toggleChatMode() {
    chatMode = chatMode === 'async' ? 'direct' : 'async';
    console.log(`🔄 Chat mode switched to: ${chatMode}`);
    
    // Save to localStorage
    if (typeof localStorage !== 'undefined') {
      localStorage.setItem('chat_mode', chatMode);
    }
    
    // Show toast notification
    if (chatMode === 'async') {
      messages = [...messages, {
        role: 'assistant',
        content: 'Switched to Async mode (gateway/webhook). Messages will be sent to the gateway for async processing.',
        timestamp: new Date()
      }];
    } else {
      messages = [...messages, {
        role: 'assistant',
        content: 'Switched to Direct mode. Messages will stream through NullClaw Gateway to your configured provider.',
        timestamp: new Date()
      }];
    }
    saveMessages();
  }

  function handleKeyPress(e: KeyboardEvent) {
    if (e.key === 'Enter' && !e.shiftKey) {
      e.preventDefault();
      sendMessage();
    }
  }

  function clearChat() {
    if (confirm('Clear all messages?')) {
      messages = [];
      saveMessages();
      
      // Generate new session ID
      sessionId = `session-${Date.now()}`;
      if (typeof localStorage !== 'undefined') {
        localStorage.setItem('chat_session_id', sessionId);
      }
    }
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
  <div class="min-h-screen flex flex-col">
    <!-- Header -->
    <header class="glass border-b border-nebula-primary/20 p-4">
      <div class="max-w-7xl mx-auto flex items-center justify-between">
        <div class="flex items-center gap-4">
          <a href="/" class="glass px-4 py-2 rounded-lg hover:bg-nebula-primary/20 transition-all flex items-center gap-2">
            <span class="text-xl">←</span>
            <span>Back</span>
          </a>
          <h1 class="text-2xl font-bold">Live Chat</h1>
        </div>
        <div class="flex items-center gap-4">
          <div class="text-xs text-gray-500">
            Session: {sessionId.slice(0, 16)}...
          </div>
          <button
            on:click={clearChat}
            class="px-4 py-2 glass hover:bg-nebula-card rounded-lg text-sm"
          >
            Clear
          </button>
        </div>
      </div>
    </header>

    <!-- Status Banner -->
    <div class="border-b border-nebula-primary/20 px-4 py-2">
      <div class="max-w-7xl mx-auto text-sm flex items-center justify-between">
        <div class="flex items-center gap-4">
          <button
            on:click={toggleChatMode}
            class={`px-3 py-1 rounded-lg text-sm font-medium transition-all ${chatMode === 'direct' ? 'bg-green-500/20 text-green-400 border border-green-500/30' : 'bg-blue-500/20 text-blue-400 border border-blue-500/30'}`}
          >
            {chatMode === 'direct' ? 'Direct Ollama' : 'Gateway Async (WhatsApp)'}
          </button>
          
          {#if chatMode === 'async'}
            {#if $gatewayConfig.connected && $gatewayConfig.paired}
              <span class="text-green-400">✅ Gateway connected - Model: {$gatewayConfig.model || 'anthropic/claude-sonnet-4'}</span>
            {:else}
              <span class="text-yellow-400">⚠️ Gateway not connected/paired</span>
            {/if}
          {:else}
            <span class="text-green-400">✅ Streaming via NullClaw Gateway - Model: {$gatewayConfig.model || 'llama3.1'}</span>
          {/if}
        </div>
        
        <div class="text-xs text-gray-400">
          {#if chatMode === 'async'}
            {$gatewayConfig.url}
          {:else}
            {$gatewayConfig.url || 'http://127.0.0.1:3000'}/v1/chat/completions
          {/if}
        </div>
      </div>
    </div>

    <!-- Polling/Streaming Indicator -->
    {#if polling}
      <div class="bg-blue-500/10 border-b border-blue-500/30 px-4 py-2">
        <div class="max-w-7xl mx-auto text-sm text-blue-400 flex items-center justify-between">
          <div class="flex items-center gap-2">
            <div class="animate-spin">⏳</div>
            <span>Waiting for agent reply... (polling {$gatewayConfig.url}/session/{sessionId}/messages every 2s)</span>
          </div>
          <div class="text-xs text-blue-300">
            Session: {sessionId.slice(0, 16)}...
          </div>
        </div>
      </div>
    {:else if streaming}
      <div class="bg-green-500/10 border-b border-green-500/30 px-4 py-2">
        <div class="max-w-7xl mx-auto text-sm text-green-400 flex items-center justify-between">
          <div class="flex items-center gap-2">
            <div class="animate-pulse">✨</div>
            <span>Streaming reply via NullClaw Gateway...</span>
          </div>
          <div class="text-xs text-green-300">
            Direct mode
          </div>
        </div>
      </div>
    {/if}

    <!-- Messages -->
    <div class="flex-1 overflow-y-auto p-8">
      <div class="max-w-4xl mx-auto space-y-6">
        {#if messages.length === 0}
          <div class="text-center text-gray-400 py-12">
            <div class="text-6xl mb-4">💬</div>
            <h2 class="text-2xl font-bold mb-2">Start a Conversation</h2>
            <p>Send a message to begin chatting</p>
            
            {#if chatMode === 'async'}
              <p class="text-sm mt-2">Using gateway at {$gatewayConfig.url}</p>
              <div class="mt-4 text-xs text-gray-500 space-y-1">
                <p>Async mode: POST to /webhook → polling {$gatewayConfig.url}/session/{sessionId}/messages</p>
                <p>Session ID: {sessionId}</p>
                <p class="text-yellow-400">Note: Session endpoint may not be implemented yet - if polling fails, check gateway logs</p>
              </div>
            {:else}
              <p class="text-sm mt-2">Using Ollama at http://localhost:11434/v1/chat/completions</p>
              <div class="mt-4 text-xs text-gray-500 space-y-1">
                <p>Direct mode: POST to /v1/chat/completions → stream response in real-time</p>
                <p>Model: llama3.1 (local)</p>
                <p class="text-green-400">Responses will stream directly from Ollama</p>
                <p class="text-yellow-400 mt-2">If Ollama is not running:</p>
                <p class="text-yellow-400 text-xs">1. Run <code>ollama serve</code> in terminal</p>
                <p class="text-yellow-400 text-xs">2. Pull model: <code>ollama pull llama3.1</code></p>
                <p class="text-yellow-400 text-xs">3. Refresh this page</p>
              </div>
            {/if}
            
            <div class="mt-6">
              <button
                on:click={toggleChatMode}
                class="px-4 py-2 glass hover:bg-nebula-card rounded-lg text-sm"
              >
                Switch to {chatMode === 'async' ? 'Direct Ollama' : 'Gateway Async'} mode
              </button>
            </div>
          </div>
        {/if}

        {#each messages as message}
          <div class={`flex ${message.role === 'user' ? 'justify-end' : 'justify-start'}`}>
            <div class={`max-w-[80%] ${message.role === 'user' ? 'bg-nebula-primary' : 'glass'} p-4 rounded-xl`}>
              <div class="flex items-center gap-2 mb-2">
                <span class="text-sm font-semibold">
                  {message.role === 'user' ? 'You' : 'NullClaw'}
                </span>
                <span class="text-xs text-gray-400">
                  {message.timestamp.toLocaleTimeString()}
                </span>
              </div>
              <p class="whitespace-pre-wrap">{message.content}</p>
            </div>
          </div>
        {/each}

        {#if polling}
          <div class="flex justify-start">
            <div class="max-w-[80%] glass p-4 rounded-xl border-2 border-blue-500/30">
              <div class="flex items-center gap-2 mb-2">
                <span class="text-sm font-semibold">NullClaw</span>
                <span class="text-xs text-blue-400 animate-pulse">processing...</span>
              </div>
              <p class="text-gray-400 text-sm">Waiting for agent reply...</p>
            </div>
          </div>
        {/if}
      </div>
    </div>

    <!-- Memory Context Panel (collapsible sidebar) -->
    {#if showMemoryPanel}
      <div class="absolute right-0 top-0 bottom-0 w-80 glass border-l border-nebula-primary/20 z-40 flex flex-col">
        <div class="p-4 border-b border-nebula-primary/20 flex items-center justify-between">
          <h3 class="font-bold">Memory Context</h3>
          <button on:click={() => showMemoryPanel = false} class="text-gray-400 hover:text-white text-xl">&times;</button>
        </div>
        <div class="flex-1 overflow-y-auto p-4 space-y-3">
          {#if $memories.length === 0}
            <p class="text-gray-500 text-sm text-center py-8">No memories yet. Go to <a href="/memory" class="text-nebula-accent hover:underline">Memory Vault</a> to add some.</p>
          {:else}
            <p class="text-xs text-gray-400 mb-2">{$memories.filter(m => m.active).length} active — included as system messages</p>
            {#each $memories as memory}
              <div class={`p-3 rounded-lg border transition-all cursor-pointer ${memory.active ? 'border-nebula-accent/50 bg-nebula-accent/10' : 'border-gray-700 bg-gray-800/50'}`}>
                <div class="flex items-center justify-between">
                  <div class="flex-1 min-w-0">
                    <div class="font-semibold text-sm truncate">{memory.name}</div>
                    <div class="text-xs text-gray-400">{memory.type} &middot; {(memory.size / 1024).toFixed(1)} KB</div>
                  </div>
                  <button
                    on:click={() => toggleMemoryActive(memory.id)}
                    class={`w-10 h-5 rounded-full transition-all relative flex-shrink-0 ml-2 ${memory.active ? 'bg-nebula-accent' : 'bg-gray-600'}`}
                  >
                    <div class={`w-4 h-4 rounded-full bg-white absolute top-0.5 transition-all ${memory.active ? 'left-5' : 'left-0.5'}`}></div>
                  </button>
                </div>
                {#if memory.active}
                  <div class="text-xs text-gray-400 mt-2 line-clamp-2">{memory.content.substring(0, 100)}...</div>
                {/if}
              </div>
            {/each}
          {/if}
        </div>
        <div class="p-3 border-t border-nebula-primary/20">
          <a href="/memory" class="block text-center text-sm text-nebula-accent hover:text-nebula-primary transition-all">Manage Memories</a>
        </div>
      </div>
    {/if}

    <!-- Input -->
    <div class="glass border-t border-nebula-primary/20 p-4">
      <div class="max-w-4xl mx-auto flex gap-4">
        <textarea
          bind:value={inputMessage}
          on:keypress={handleKeyPress}
          placeholder="Type your message... (Enter to send, Shift+Enter for new line)"
          disabled={sending || polling || streaming}
          class="flex-1 glass px-4 py-3 rounded-lg focus:outline-none focus:ring-2 focus:ring-nebula-primary resize-none"
          rows="2"
        ></textarea>
        <div class="flex flex-col gap-2">
          <button
            on:click={sendMessage}
            disabled={sending || polling || streaming || !inputMessage.trim()}
            class="px-8 py-3 bg-nebula-primary hover:bg-nebula-primaryLight disabled:opacity-50 disabled:cursor-not-allowed rounded-lg font-semibold"
          >
            {sending ? 'Sending...' : polling ? 'Waiting...' : streaming ? 'Streaming...' : 'Send'}
          </button>
          <button
            on:click={() => showMemoryPanel = !showMemoryPanel}
            class={`px-4 py-1 text-xs rounded-lg transition-all ${$memories.filter(m => m.active).length > 0 ? 'bg-nebula-accent/20 text-nebula-accent border border-nebula-accent/30' : 'glass text-gray-400'}`}
            title="Toggle memory context panel"
          >
            {$memories.filter(m => m.active).length > 0 ? `${$memories.filter(m => m.active).length} memories` : 'Memories'}
          </button>
        </div>
      </div>
    </div>
  </div>
{/if}
