import { useEffect } from 'react';

const SPEED_S = process.env.NEXT_PUBLIC_STAR_SPEED_S || '50s';
const SPEED_M = process.env.NEXT_PUBLIC_STAR_SPEED_M || '100s';
const SPEED_L = process.env.NEXT_PUBLIC_STAR_SPEED_L || '150s';

const PAR_S = process.env.NEXT_PUBLIC_STAR_PARALLAX_S || '-0.20';
const PAR_M = process.env.NEXT_PUBLIC_STAR_PARALLAX_M || '-0.35';
const PAR_L = process.env.NEXT_PUBLIC_STAR_PARALLAX_L || '-0.55';

export default function useStarConfig() {
  useEffect(() => {
    const root = document.documentElement;
    root.style.setProperty('--star-speed-s', SPEED_S);
    root.style.setProperty('--star-speed-m', SPEED_M);
    root.style.setProperty('--star-speed-l', SPEED_L);
    root.style.setProperty('--star-parallax-s', PAR_S);
    root.style.setProperty('--star-parallax-m', PAR_M);
    root.style.setProperty('--star-parallax-l', PAR_L);
  }, []);
}

