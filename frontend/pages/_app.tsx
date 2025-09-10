import '../styles/global.scss';
import '../styles/parallax-globals.scss';
import type { AppProps } from 'next/app';
import '../styles/globals.scss';
import ThemeToggle from '../components/ThemeToggle';
import Starfield from '../components/Starfield';
import useScrollParallax from '../hooks/useScrollParallax';
export default function App({ Component, pageProps }: AppProps) {
  useScrollParallax();
  return (
    <>
      <Starfield />
      <div className="header" style={{ position: 'relative', zIndex: 1 }}>
        <strong>Wallet Recoverer</strong>
        <div style={{ marginLeft: 'auto' }}><ThemeToggle /></div>
      </div>
      <div style={{ position: 'relative', zIndex: 1 }}>
        <Component {...pageProps} />
      </div>
    </>
  );
}
