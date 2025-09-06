import React from 'react';

export default function ThemeToggle() {
  const [theme, setTheme] = React.useState<string | null>(null);

  React.useEffect(() => {
    // hydration-safe read
    const saved = typeof window !== 'undefined' ? localStorage.getItem('theme') : null;
    if (saved === 'light' || saved === 'dark') {
      setTheme(saved);
      document.documentElement.setAttribute('data-theme', saved);
    } else {
      // fallback to prefers-color-scheme
      const prefersDark = typeof window !== 'undefined' &&
        window.matchMedia && window.matchMedia('(prefers-color-scheme: dark)').matches;
      const initial = prefersDark ? 'dark' : 'light';
      setTheme(initial);
      document.documentElement.setAttribute('data-theme', initial);
      localStorage.setItem('theme', initial);
    }
  }, []);

  const toggle = () => {
    const next = theme === 'dark' ? 'light' : 'dark';
    setTheme(next);
    document.documentElement.setAttribute('data-theme', next);
    localStorage.setItem('theme', next);
  };

  return (
    <button aria-label="Toggle color scheme" onClick={toggle} style={{marginLeft: 'auto'}}>
      {theme === 'dark' ? '🌙 Dark' : '☀️ Light'}
    </button>
  );
}
