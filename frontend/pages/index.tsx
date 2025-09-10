import Head from 'next/head';

type Props = { project: string; parallax: boolean; backendStatus: string };

export async function getServerSideProps() {
  const project = process.env.PROJECT_NAME ?? 'wallet-recoverer';
  const parallax = (process.env.NEXT_PUBLIC_PARALLAX ?? '1') === '1';
  const base = process.env.NEXT_PUBLIC_BE_URL ?? 'http://localhost:8000';
  let backendStatus = 'unknown';
  try {
    const res = await fetch(`${base}/health`, { cache: 'no-store' });
    backendStatus = res.ok ? (await res.json())?.status ?? 'unknown' : `http ${res.status}`;
  } catch {
    backendStatus = 'unreachable';
  }
  return { props: { project, parallax, backendStatus } };
}

export default function Home({ project, parallax, backendStatus }: Props) {
  return (
    <>
      <Head><title>{project}</title></Head>
      {parallax && (
        <section className="parallax parallax--hero" aria-label="Decorative animated background">
          <div className="p-slow"><span className="gradient">PURE CSS</span></div>
          <div className="p-med"><span className="gradient">PARALLAX PIXEL STARS</span></div>
        </section>
      )}
      <main className="container">
        <p className="hint">Watch-only wallet recovery — educational and defensive.</p>
        <p><strong>Backend:</strong> <span className="badge">{backendStatus}</span></p>
        <span className="badge">Step 2(d): Theme toggle + dual parallax</span>
      </main>
    </>
  );
}
