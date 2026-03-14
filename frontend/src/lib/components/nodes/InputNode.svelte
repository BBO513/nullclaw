<svelte:options runes={false} />

<script lang="ts">
  import { Handle, Position } from '@xyflow/svelte';
  
  export let data: any;
  export let selected: boolean = false;
</script>

<div class="input-node glass p-4 rounded-lg border-2 transition-all {selected ? 'border-green-500 shadow-lg shadow-green-500/50' : 'border-green-500/30'}">
  <div class="flex items-center gap-2">
    <span class="text-2xl">📥</span>
    <div class="flex-1">
      <div class="font-bold text-sm">{data.label || 'Input'}</div>
      <div class="text-xs text-gray-400">{data.role || 'input'}</div>
    </div>
  </div>
  
  <Handle type="source" position={Position.Right} />
</div>

<style>
  .input-node {
    min-width: 160px;
    background: rgba(17, 17, 24, 0.95);
  }
  
  .input-node:hover {
    border-color: rgba(34, 197, 94, 0.8);
    box-shadow: 0 0 20px rgba(34, 197, 94, 0.3);
  }
</style>
