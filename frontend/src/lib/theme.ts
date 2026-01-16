/**
 * Theme management utilities
 */

export type ThemeMode = 'light' | 'dark';

const THEME_STORAGE_KEY = 'theme-mode';

/**
 * Get stored theme mode from localStorage
 */
export function getStoredThemeMode(): ThemeMode {
    if (typeof window === 'undefined') return 'dark';
    
    const stored = localStorage.getItem(THEME_STORAGE_KEY);
    if (stored === 'light' || stored === 'dark') {
        return stored;
    }
    
    // Check system preference
    if (window.matchMedia && window.matchMedia('(prefers-color-scheme: light)').matches) {
        return 'light';
    }
    
    return 'dark';
}

/**
 * Apply theme mode to document
 */
export function applyThemeMode(mode: ThemeMode): void {
    if (typeof document === 'undefined') return;
    
    const root = document.documentElement;
    
    if (mode === 'dark') {
        root.classList.add('dark');
    } else {
        root.classList.remove('dark');
    }
    
    // Store preference
    if (typeof window !== 'undefined') {
        localStorage.setItem(THEME_STORAGE_KEY, mode);
    }
}

/**
 * Initialize theme on app load
 */
export function initTheme(defaultMode: ThemeMode = 'dark'): void {
    const mode = getStoredThemeMode() || defaultMode;
    applyThemeMode(mode);
}

/**
 * Set theme mode (alias for applyThemeMode for consistency)
 */
export function setThemeMode(mode: ThemeMode): void {
    applyThemeMode(mode);
}

/**
 * Toggle between light and dark mode
 */
export function toggleTheme(): ThemeMode {
    const current = getStoredThemeMode();
    const newMode = current === 'dark' ? 'light' : 'dark';
    applyThemeMode(newMode);
    return newMode;
}

