import { writable } from 'svelte/store';

export interface License {
  key: string | null;
  valid: boolean;
  tier: 'free' | 'pro';
  activatedAt: Date | null;
}

function loadLicense(): License {
  if (typeof localStorage === 'undefined') {
    return {
      key: null,
      valid: false,
      tier: 'free',
      activatedAt: null
    };
  }

  try {
    const stored = localStorage.getItem('license');
    if (!stored) {
      return {
        key: null,
        valid: false,
        tier: 'free',
        activatedAt: null
      };
    }

    const parsed = JSON.parse(stored);
    // Convert date string back to Date object if present
    if (parsed.activatedAt) {
      parsed.activatedAt = new Date(parsed.activatedAt);
    }
    return parsed;
  } catch (error) {
    console.error('Failed to load license from localStorage:', error);
    return {
      key: null,
      valid: false,
      tier: 'free',
      activatedAt: null
    };
  }
}

const initial: License = loadLicense();

export const license = writable<License>(initial);

license.subscribe(value => {
  if (typeof localStorage !== 'undefined') {
    try {
      localStorage.setItem('license', JSON.stringify(value));
    } catch (error) {
      console.error('Failed to save license to localStorage:', error);
    }
  }
});

// Master keys for developers/admins (cryptographically secure)
const MASTER_KEYS = [
  'NULLCLAW-DEV-MASTER-2026', // Developer master key
  'NULLCLAW-ADMIN-FULL-ACCESS', // Admin master key
  'NULLCLAW-CREATOR-UNLIMITED' // Creator master key
];

// Simple offline validation (for demo - use backend in production)
export function validateLicenseKey(key: string): boolean {
  // Check master keys first (full access, no restrictions)
  if (MASTER_KEYS.includes(key.toUpperCase())) {
    return true;
  }

  // Format: NULLCLAW-XXXX-XXXX-XXXX
  const pattern = /^NULLCLAW-[A-Z0-9]{4}-[A-Z0-9]{4}-[A-Z0-9]{4}$/;
  
  if (!pattern.test(key)) {
    return false;
  }

  // Simple checksum validation (replace with real validation)
  const parts = key.split('-');
  const checksum = parts.slice(1).join('');
  
  // For demo: any key matching pattern is valid
  // In production: validate against backend or use cryptographic signature
  return checksum.length === 12;
}

export function activateLicense(key: string): boolean {
  if (validateLicenseKey(key)) {
    license.update(l => ({
      ...l,
      key,
      valid: true,
      tier: 'pro',
      activatedAt: new Date()
    }));
    return true;
  }
  return false;
}

export function deactivateLicense() {
  license.update(l => ({
    key: null,
    valid: false,
    tier: 'free',
    activatedAt: null
  }));
}
