<svelte:options runes={false} />

<script lang="ts">
  import { Handle, Position } from '@xyflow/svelte';
  
  export let data: any;
  export let selected: boolean = false;
</script>

<div class="output-node glass p-4 rounded-lg border-2 transition-all {selected ? 'border-blue-500 shadow-lg shadow-blue-500/50' : 'border-blue-500/30'}">
  <div class="flex items-center gap-2">
    <span class="text-2xl">📤</span>
    <div class="flex-1">
      <div class="font-bold text-sm">{data.label || 'Output'}</div>
      <div class="text-xs text-gray-400">{data.role || 'output'}</div>
    </div>
  </div>
  
  <Handle type="target" position={Position.Left} />
</div>

<style>
  .output-node {
    min-width: 160px;
    background: rgba(17, 17, 24, 0.95);
  }
  
  .output-node:hover {
    border-color: rgba(59, 130, 246, 0.8);
    box-shadow: 0 0 20px rgba(59, 130, 246, 0.3);
  }
</style>
