import { useEffect, useRef } from 'react';
import styles from '../styles/parallax-test.module.scss';

export default function ParallaxTester() {
  const containerRef = useRef<HTMLDivElement | null>(null);

  useEffect(() => {
    const el = containerRef.current;
    if (!el) return;

    const layers = Array.from(el.querySelectorAll<HTMLElement>('[data-speed]'));

    let raf = 0;
    const onScroll = () => {
      cancelAnimationFrame(raf);
      raf = requestAnimationFrame(() => {
        const y = window.scrollY || window.pageYOffset || 0;
        for (const layer of layers) {
          const speed = Number(layer.dataset.speed || '0');
          // translateZ(0) to force GPU; works better than background-attachment on iOS
          layer.style.transform = `translate3d(0, ${y * speed}px, 0)`;
        }
      });
    };

    window.addEventListener('scroll', onScroll, { passive: true });
    onScroll();
    return () => {
      cancelAnimationFrame(raf);
      window.removeEventListener('scroll', onScroll);
    };
  }, []);

  return (
    <div ref={containerRef} className={styles.wrap}>
      <section className={styles.hero}>
        <h1>Parallax Test</h1>
        <p className={styles.badge}>Toggle dark/light and scroll</p>
      </section>

      {/* two independent parallax layers */}
      <div className={styles.layerBack} data-speed="0.15" aria-hidden="true" />
      <div className={styles.layerMid} data-speed="0.30" aria-hidden="true" />

      <section className={styles.filler}>
        <h3>Scrollable Content</h3>
        <p>Keep scrolling—layers should drift at different speeds.</p>
      </section>
      <section className={styles.filler}>
        <p>This helps visual-verify parallax works on your device.</p>
      </section>
    </div>
  );
}
