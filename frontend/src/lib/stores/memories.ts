import { writable } from 'svelte/store';

export interface Memory {
  id: string;
  name: string;
  content: string;
  type: 'prompt' | 'knowledge' | 'context';
  size: number;
  createdAt: Date;
  relevance?: number;
  active: boolean;
  injectedAt?: Date;
}

// Load memories from localStorage
function loadMemories(): Memory[] {
  if (typeof localStorage === 'undefined') return [];
  try {
    const saved = localStorage.getItem('nullclaw_memories');
    if (!saved) return [];
    const parsed = JSON.parse(saved);
    return parsed.map((m: Record<string, unknown>) => ({
      ...m,
      createdAt: new Date(m.createdAt as string),
      injectedAt: m.injectedAt ? new Date(m.injectedAt as string) : undefined,
      active: (m.active as boolean) ?? false,
    }));
  } catch {
    return [];
  }
}

export const memories = writable<Memory[]>(loadMemories());

// Persist to localStorage on changes
memories.subscribe(value => {
  if (typeof localStorage !== 'undefined') {
    try {
      localStorage.setItem('nullclaw_memories', JSON.stringify(value));
    } catch (error) {
      console.error('Failed to save memories to localStorage:', error);
    }
  }
});

/**
 * Get all active memories formatted as system messages for chat context.
 */
export function getActiveMemoryMessages(mems: Memory[]): Array<{ role: 'system'; content: string }> {
  const active = mems.filter(m => m.active);
  if (active.length === 0) return [];

  return active.map(m => ({
    role: 'system' as const,
    content: `[Memory: ${m.name}] (${m.type})\n${m.content}`
  }));
}

/**
 * Toggle a memory's active state
 */
export function toggleMemoryActive(id: string) {
  memories.update(mems =>
    mems.map(m =>
      m.id === id
        ? { ...m, active: !m.active, injectedAt: !m.active ? new Date() : undefined }
        : m
    )
  );
}

/**
 * Set all memories active or inactive
 */
export function setAllMemoriesActive(active: boolean) {
  memories.update(mems =>
    mems.map(m => ({
      ...m,
      active,
      injectedAt: active ? new Date() : undefined
    }))
  );
}
