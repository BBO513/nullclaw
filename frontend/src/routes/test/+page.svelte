<script lang="ts">
  let count = $state(0);
</script>

<div class="p-8">
  <h1 class="text-2xl">Test Page</h1>
  <p>Count: {count}</p>
  <button on:click={() => count++} class="px-4 py-2 bg-blue-500 text-white rounded">
    Increment
  </button>
</div>
