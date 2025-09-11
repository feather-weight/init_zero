import '../styles/global.scss';
import '../styles/parallax-globals.scss';
import type { AppProps } from 'next/app';
import '../styles/globals.scss';
import ThemeToggle from '../components/ThemeToggle';
import Starfield from '../components/Starfield';
import useScrollParallax from '../hooks/useScrollParallax';
import useStarConfig from '../hooks/useStarConfig';
import { useState } from 'react';
import RegisterModal from '../components/RegisterModal';
import AuthModal from '../components/AuthModal';
export default function App({ Component, pageProps }: AppProps) {
  useScrollParallax();
  useStarConfig();
  const [showRegister, setShowRegister] = useState(false)
  const [showAuth, setShowAuth] = useState(false)
  return (
    <>
      <Starfield />
      <div className="header" style={{ position: 'relative', zIndex: 1 }}>
        <strong>Wallet Recoverer</strong>
        <div style={{ marginLeft: 'auto' }}><ThemeToggle /></div>
        <button className="btn" style={{ marginLeft: '.75rem' }} onClick={()=>setShowRegister(true)}>Register</button>
        <button className="btn" style={{ marginLeft: '.5rem' }} onClick={()=>setShowAuth(true)}>Sign In</button>
      </div>
      <div style={{ position: 'relative', zIndex: 1 }}>
        <Component {...pageProps} />
      </div>
      {showRegister && <RegisterModal onClose={()=>setShowRegister(false)} />}
      {showAuth && <AuthModal onClose={()=>setShowAuth(false)} />}
    </>
  );
}
