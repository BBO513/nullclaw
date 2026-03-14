import { writable } from 'svelte/store';

export interface Agent {
  id: string;
  name: string;
  mode: 'manual' | 'autonomous' | 'planning';
  status: 'idle' | 'active' | 'thinking';
  model?: string;
}

export const agents = writable<Agent[]>([
  {
    id: '1',
    name: 'Default Agent',
    mode: 'manual',
    status: 'idle'
  }
]);

export const activeAgent = writable<string>('1');
