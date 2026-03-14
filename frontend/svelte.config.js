import adapter from '@sveltejs/adapter-static';

/** @type {import('@sveltejs/kit').Config} */
const config = {
	kit: {
		adapter: adapter({
			// Output to 'build' folder for easy distribution
			pages: 'build',
			assets: 'build',
			fallback: 'index.html',
			precompress: false,
			strict: true
		})
	},
	compilerOptions: {
		runes: true  // Enable Svelte 5 runes mode ($state, $derived, $effect)
	}
};

export default config;
