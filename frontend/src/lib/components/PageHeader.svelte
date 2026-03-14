<script lang="ts">
  export let title: string;
  export let subtitle: string | undefined = undefined;
  export let showBack: boolean = true;

  function goBack() {
    window.history.back();
  }
</script>

<header class="mb-8">
  <div class="flex items-center gap-4 mb-4">
    {#if showBack}
      <button
        on:click={goBack}
        class="glass px-4 py-2 rounded-lg hover:bg-nebula-primary/20 transition-all flex items-center gap-2"
      >
        <span class="text-xl">←</span>
        <span>Back</span>
      </button>
    {/if}
  </div>
  <h1 class="text-4xl font-bold bg-gradient-to-r from-nebula-primary to-nebula-accent bg-clip-text text-transparent">
    {title}
  </h1>
  {#if subtitle}
    <p class="text-gray-400 mt-2">{subtitle}</p>
  {/if}
</header>
