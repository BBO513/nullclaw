import { writable } from 'svelte/store';

export type Theme = 'nebula' | 'void' | 'eclipse';

export const currentTheme = writable<Theme>('nebula');

export const proUnlocked = writable<boolean>(false);
