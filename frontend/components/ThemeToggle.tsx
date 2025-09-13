import { useEffect, useState } from 'react';

type Theme = 'light' | 'dark';

function getInitial(): Theme {
  if (typeof window === 'undefined') return 'light';
  const saved = localStorage.getItem('theme');
  if (saved === 'dark' || saved === 'light') return saved;
  return window.matchMedia('(prefers-color-scheme: dark)').matches ? 'dark' : 'light';
}

export default function ThemeToggle() {
  // Start with a stable default and avoid theme-specific render until mounted.
  const [theme, setTheme] = useState<Theme>('light');
  const [mounted, setMounted] = useState(false);

  useEffect(() => {
    // Resolve actual initial theme on client only
    const initial = getInitial();
    setTheme(initial);
    setMounted(true);
  }, []);

  useEffect(() => {
    document.documentElement.setAttribute('data-theme', theme);
    try {
      localStorage.setItem('theme', theme);
    } catch {}
  }, [theme]);

  const label = theme === 'dark' ? '🌙 Dark' : '☀️ Light';

  return (
    <button onClick={() => setTheme(theme === 'dark' ? 'light' : 'dark')}>
      {mounted ? label : 'Theme'}
    </button>
  );
}
