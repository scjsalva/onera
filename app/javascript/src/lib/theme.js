// Theme is one of 'system' | 'light' | 'dark'. 'system' follows the OS and
// keeps following it when the OS changes, which is the behaviour people
// actually expect from an Apple-style appearance setting.

const KEY = 'onera:theme';
const media = () => window.matchMedia('(prefers-color-scheme: dark)');

export function storedTheme() {
  try {
    return localStorage.getItem(KEY) || 'system';
  } catch {
    return 'system';
  }
}

export function resolvedTheme(preference = storedTheme()) {
  if (preference === 'system') return media().matches ? 'dark' : 'light';
  return preference;
}

export function applyTheme(preference = storedTheme()) {
  const resolved = resolvedTheme(preference);
  document.documentElement.classList.toggle('dark', resolved === 'dark');

  const meta = document.querySelector('meta[name="theme-color"]');
  if (meta) meta.content = resolved === 'dark' ? '#101216' : '#f1f3f5';

  return resolved;
}

export function setTheme(preference) {
  try {
    if (preference === 'system') localStorage.removeItem(KEY);
    else localStorage.setItem(KEY, preference);
  } catch {
    /* private browsing - the choice just won't persist */
  }
  return applyTheme(preference);
}

export function watchSystemTheme() {
  media().addEventListener('change', () => {
    if (storedTheme() === 'system') applyTheme('system');
  });
}
