<script lang="ts">
  import { onMount } from 'svelte';

  let deferredPrompt: any = null;
  let showPrompt = false;
  let interactionCount = 0;
  let installing = false;

  onMount(() => {
    // Check if already installed
    if (window.matchMedia('(display-mode: standalone)').matches) {
      console.log('[PWA] Already installed');
      return;
    }

    // Check if prompt was dismissed
    const dismissed = localStorage.getItem('pwa-install-dismissed');
    if (dismissed) {
      const dismissedTime = parseInt(dismissed);
      const daysSinceDismissed = (Date.now() - dismissedTime) / (1000 * 60 * 60 * 24);
      if (daysSinceDismissed < 7) {
        console.log('[PWA] Install prompt dismissed recently');
        return;
      }
    }

    // Listen for beforeinstallprompt event
    window.addEventListener('beforeinstallprompt', (e) => {
      console.log('[PWA] beforeinstallprompt fired');
      e.preventDefault();
      deferredPrompt = e;
    });

    // Track interactions
    const trackInteraction = () => {
      interactionCount++;
      localStorage.setItem('pwa-interaction-count', interactionCount.toString());
      
      // Show prompt after 3 interactions
      if (interactionCount >= 3 && deferredPrompt && !showPrompt) {
        setTimeout(() => {
          showPrompt = true;
        }, 1000);
      }
    };

    // Load interaction count
    const savedCount = localStorage.getItem('pwa-interaction-count');
    if (savedCount) {
      interactionCount = parseInt(savedCount);
    }

    // Track clicks and navigation
    document.addEventListener('click', trackInteraction);
    
    // Show prompt if already have enough interactions
    if (interactionCount >= 3 && deferredPrompt) {
      setTimeout(() => {
        showPrompt = true;
      }, 2000);
    }

    return () => {
      document.removeEventListener('click', trackInteraction);
    };
  });

  async function handleInstall() {
    if (!deferredPrompt) {
      console.log('[PWA] No deferred prompt available');
      return;
    }

    installing = true;

    try {
      // Show the install prompt
      deferredPrompt.prompt();

      // Wait for the user's response
      const { outcome } = await deferredPrompt.userChoice;
      console.log('[PWA] User choice:', outcome);

      if (outcome === 'accepted') {
        console.log('[PWA] User accepted the install prompt');
      } else {
        console.log('[PWA] User dismissed the install prompt');
      }

      // Clear the deferred prompt
      deferredPrompt = null;
      showPrompt = false;
    } catch (error) {
      console.error('[PWA] Install error:', error);
    } finally {
      installing = false;
    }
  }

  function handleDismiss() {
    showPrompt = false;
    localStorage.setItem('pwa-install-dismissed', Date.now().toString());
  }
</script>

{#if showPrompt}
  <div class="fixed bottom-4 left-4 right-4 md:left-auto md:right-4 md:w-96 z-50 animate-slide-up">
    <div class="glass p-6 rounded-xl border-2 border-nebula-primary/30">
      <div class="flex items-start gap-4">
        <div class="text-4xl">📱</div>
        <div class="flex-1">
          <h3 class="text-lg font-bold mb-2">Install NullClaw Nexus</h3>
          <p class="text-sm text-gray-400 mb-4">
            Install as an app for quick access and offline support. Works on desktop and mobile.
          </p>
          <div class="flex gap-2">
            <button
              on:click={handleDismiss}
              class="flex-1 px-4 py-2 glass hover:bg-nebula-card rounded-lg text-sm"
              disabled={installing}
            >
              Not Now
            </button>
            <button
              on:click={handleInstall}
              disabled={installing}
              class="flex-1 px-4 py-2 bg-nebula-primary hover:bg-nebula-primaryLight disabled:opacity-50 rounded-lg font-semibold text-sm"
            >
              {installing ? 'Installing...' : 'Install'}
            </button>
          </div>
        </div>
        <button
          on:click={handleDismiss}
          class="text-gray-400 hover:text-white"
          disabled={installing}
        >
          ✕
        </button>
      </div>
    </div>
  </div>
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
