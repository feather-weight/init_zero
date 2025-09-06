import Head from 'next/head';

type Props = { project: string; backendStatus: string };

export async function getServerSideProps() {
  const project = process.env.PROJECT_NAME ?? 'wallet-recoverer';
  const base = process.env.NEXT_PUBLIC_BACKEND_URL ?? 'http://localhost:8000';
  let backendStatus = 'unknown';
  try {
    const res = await fetch(`${base}/health`, { cache: 'no-store' });
    if (res.ok) {
      const j = await res.json();
      backendStatus = j?.status ?? 'unknown';
    } else {
      backendStatus = `http ${res.status}`;
    }
  } catch (e) {
    backendStatus = 'unreachable';
  }
  return { props: { project, backendStatus } };
}

export default function Home({ project, backendStatus }: Props) {
  return (
    <>
      <Head><title>{project}</title></Head>
      <main className="container">
        <h1>{project}</h1>
        <p className="hint">Watch-only wallet recovery — educational and defensive.</p>
        <p><strong>Backend:</strong> <span className="badge">{backendStatus}</span></p>
        <span className="badge">Step 2(c): Frontend ↔ Backend wired via env URL</span>
      </main>
    </>
  );
}
