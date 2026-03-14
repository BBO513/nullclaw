<script lang="ts">
	import '../app.css';
	import ErrorBoundary from '$lib/components/ErrorBoundary.svelte';
	import OfflineIndicator from '$lib/components/OfflineIndicator.svelte';
	import InstallPrompt from '$lib/components/InstallPrompt.svelte';
	import { onMount } from 'svelte';
	import { gatewayConfig, autoDiscoverGateway } from '$lib/stores/gateway';
	import { GatewayAPI } from '$lib/api/gateway';
	import { isTauri, onGatewayStarted } from '$lib/tauri';
	import { get } from 'svelte/store';

	let autoPairingAttempted = false;

	onMount(async () => {
		// Unregister all service workers to prevent caching issues (not needed in Tauri)
		if (!isTauri() && 'serviceWorker' in navigator) {
			navigator.serviceWorker.getRegistrations().then((registrations) => {
				for (let registration of registrations) {
					registration.unregister();
					console.log('[PWA] Service Worker unregistered');
				}
			});
		}

		// Auto-discover gateway (tries multiple ports, works in both Tauri and browser)
		const discoveredUrl = await autoDiscoverGateway();
		if (discoveredUrl) {
			console.log('[Gateway] Connected to:', discoveredUrl);
		}

		// In Tauri, listen for gateway-started events from the sidecar
		if (isTauri()) {
			onGatewayStarted((url) => {
				console.log('[Tauri] Gateway sidecar started at:', url);
				gatewayConfig.update(c => ({ ...c, url, connected: true }));
			});
		}

		// Auto-pair on first launch if no token exists
		const config = get(gatewayConfig);
		if (!config.bearerToken && !config.paired && !autoPairingAttempted) {
			autoPairingAttempted = true;
			console.log('[Auto-Pair] No token found, attempting auto-pairing with master key...');
			
			try {
				const api = new GatewayAPI(config.url);
				const result = await api.pairWithMasterKey('NULLCLAW-CREATOR-UNLIMITED');
				
				if (result && result.token) {
					gatewayConfig.update(c => ({
						...c,
						bearerToken: result.token,
						paired: true,
						connected: true
					}));
					console.log('[Auto-Pair] Successfully auto-paired with master key');
				} else {
					console.log('[Auto-Pair] Master key pairing failed, user will need to pair manually');
				}
			} catch (error) {
				console.log('[Auto-Pair] Auto-pairing failed:', error);
				// Silent fail - user can pair manually later
			}
		}
	});
</script>

<svelte:head>
	<link rel="icon" href="/favicon.svg" />
	<link rel="manifest" href="/manifest.json" />
	<meta name="theme-color" content="#7c3aed" />
	<meta name="apple-mobile-web-app-capable" content="yes" />
	<meta name="apple-mobile-web-app-status-bar-style" content="black-translucent" />
	<meta name="apple-mobile-web-app-title" content="NullClaw Nexus" />
</svelte:head>

<ErrorBoundary>
	<OfflineIndicator />
	<InstallPrompt />
	<div class="dark min-h-screen">
		<slot />
	</div>
</ErrorBoundary>
