import '../styles/parallax-globals.scss';
import type { AppProps } from 'next/app';
import '../styles/globals.scss';
import ThemeToggle from '../components/ThemeToggle';
export default function App({ Component, pageProps }: AppProps) {
  return (
    <>
      <div className="header">
        <strong>Wallet Recoverer</strong>
        <div style={{ marginLeft: 'auto' }}><ThemeToggle /></div>
      </div>
      <Component {...pageProps} />
    </>
  );
}
