import type { AppProps } from 'next/app';
import '../styles/globals.scss';
import ThemeToggle from '../components/ThemeToggle';
import { useEffect } from 'react';

export default function App({ Component, pageProps }: AppProps) {
  // On mount, ensure the HTML element has a data-theme attribute.
  useEffect(() => {
    const saved = localStorage.getItem('theme');
    const prefersDark = window.matchMedia('(prefers-color-scheme: dark)').matches;
    const initial = (saved as 'light' | 'dark' | null) ?? (prefersDark ? 'dark' : 'light');
    document.documentElement.setAttribute('data-theme', initial);
    localStorage.setItem('theme', initial);
  }, []);

  return (
    <>
      <header style={{ display: 'flex', alignItems: 'center', gap: '1rem', padding: '0.75rem 1rem' }}>
        <strong>wallet‑recoverer</strong>
        <ThemeToggle />
      </header>
      <Component {...pageProps} />
    </>
  );
}
