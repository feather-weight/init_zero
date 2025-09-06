import type { AppProps } from 'next/app';
import '../styles/globals.scss';
import ThemeToggle from '../components/ThemeToggle';

export default function App({ Component, pageProps }: AppProps) {
  return (
    <>
      <header style={{display:'flex', alignItems:'center', gap:'1rem', padding:'0.75rem 1rem'}}>
        <strong>wallet-recoverer</strong>
        <ThemeToggle />
      </header>
      <Component {...pageProps} />
    </>
  );
}
