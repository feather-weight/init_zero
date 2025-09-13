import Head from 'next/head'

export default function Home() {
  const apiBase = process.env.NEXT_PUBLIC_API_BASE || 'http://localhost:8000';
  return (
    <>
      <Head>
        <title>Step Zero</title>
        <meta name="viewport" content="width=device-width, initial-scale=1" />
      </Head>
      <main style={{ padding: 24, fontFamily: 'system-ui, sans-serif' }}>
        <h1>Step Zero</h1>
        <p>Frontend is up. Backend at: {apiBase}</p>
      </main>
    </>
  )
}

