import React, { useEffect, useState } from 'react';

export default function ThemeToggle() {
  // Hydration-safe theme state.  We initialise undefined and then set
  // from localStorage or prefers-color-scheme in useEffect.
  const [theme, setTheme] = useState<'light' | 'dark'>();

  // On mount, set the initial theme.
  useEffect(() => {
    const saved = typeof window !== 'undefined'
      ? (localStorage.getItem('theme') as 'light' | 'dark' | null)
      : null;
    const prefersDark = typeof window !== 'undefined'
      && window.matchMedia
      && window.matchMedia('(prefers-color-scheme: dark)').matches;
    const initial = saved ?? (prefersDark ? 'dark' : 'light');
    setTheme(initial);
    document.documentElement.setAttribute('data-theme', initial);
    localStorage.setItem('theme', initial);
  }, []);

  // Toggle handler
  const flip = () => {
    const next: 'light' | 'dark' = theme === 'dark' ? 'light' : 'dark';
    setTheme(next);
    document.documentElement.setAttribute('data-theme', next);
    localStorage.setItem('theme', next);
  };

  // Render a simple button with emoji indicator. Avoid SSR mismatch by
  // defaulting to null until theme is set.
  return (
    <button onClick={flip} aria-label="Toggle colour theme">
      {theme === 'dark' ? '🌙 Dark' : '☀️ Light'}
    </button>
  );
}
