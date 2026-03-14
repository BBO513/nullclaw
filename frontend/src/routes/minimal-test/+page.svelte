<script>
  let count = 0;
</script>

<div style="padding: 40px; background: white; color: black;">
  <h1 style="color: red; font-size: 48px;">MINIMAL TEST PAGE</h1>
  <p style="font-size: 24px;">If you can see this, Svelte is working!</p>
  <p style="font-size: 20px;">Count: {count}</p>
  <button 
    on:click={() => count++}
    style="padding: 20px; font-size: 20px; background: blue; color: white; border: none; cursor: pointer;"
  >
    Click Me
  </button>
</div>
