<svelte:options runes={false} />

<script lang="ts">
  import { Handle, Position } from '@xyflow/svelte';
  
  export let data: any;
  export let selected: boolean = false;
</script>

<div class="agent-node glass p-4 rounded-lg border-2 transition-all {selected ? 'border-nebula-primary shadow-lg shadow-nebula-primary/50' : 'border-nebula-primary/30'}">
  <div class="flex items-center gap-2 mb-2">
    <span class="text-2xl">🤖</span>
    <div class="flex-1">
      <div class="font-bold text-sm">{data.label || 'Agent'}</div>
      <div class="text-xs text-gray-400">{data.role || 'worker'}</div>
    </div>
  </div>
  {#if data.model}
    <div class="text-xs text-nebula-primary/70 mt-1">{data.model}</div>
  {/if}
  
  <Handle type="target" position={Position.Left} />
  <Handle type="source" position={Position.Right} />
</div>

<style>
  .agent-node {
    min-width: 180px;
    background: rgba(17, 17, 24, 0.95);
  }
  
  .agent-node:hover {
    border-color: rgba(124, 58, 237, 0.8);
    box-shadow: 0 0 20px rgba(124, 58, 237, 0.3);
  }
</style>
