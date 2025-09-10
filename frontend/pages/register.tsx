import { useState } from 'react'

export default function Register() {
  const [handle, setHandle] = useState('')
  const [email, setEmail] = useState('')
  const [publicKey, setPublicKey] = useState('')
  const [result, setResult] = useState<string>('')
  const base = process.env.NEXT_PUBLIC_BE_URL || 'http://localhost:8000'

  const onSubmit = async (e: React.FormEvent) => {
    e.preventDefault()
    setResult('')
    try {
      const res = await fetch(`${base}/auth/register`, {
        method: 'POST', headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ handle, email, public_key: publicKey })
      })
      const data = await res.json()
      if (!res.ok) throw new Error(data?.detail || 'Registration failed')
      setResult('Submitted. Await manual approval via email.')
    } catch (e: any) {
      setResult(`Error: ${e.message || String(e)}`)
    }
  }

  return (
    <main className="container" style={{paddingBottom:'3rem'}}>
      <h1>Register</h1>
      <form onSubmit={onSubmit} style={{display:'grid', gap: '.75rem', maxWidth: 680}}>
        <label>
          Desired handle
          <span title="3–32 chars; letters, numbers, _ or - only" style={{marginLeft:'.25rem'}}>ⓘ</span>
          <input placeholder="handle" value={handle} onChange={e=>setHandle(e.target.value)} />
        </label>
        <label>
          Verifiable email
          <span title="We will contact and verify ownership (KYC)" style={{marginLeft:'.25rem'}}>ⓘ</span>
          <input placeholder="you@example.com" value={email} onChange={e=>setEmail(e.target.value)} />
        </label>
        <label>
          Public PGP key (ASCII-armor)
          <span title="Use a strong 4096-bit key with passphrase; do not use web key generators." style={{marginLeft:'.25rem'}}>ⓘ</span>
          <textarea rows={10} placeholder="-----BEGIN PGP PUBLIC KEY BLOCK-----" value={publicKey} onChange={e=>setPublicKey(e.target.value)} />
        </label>
        <button className="btn" type="submit">Submit for Approval</button>
      </form>
      {result && <p className="hint">{result}</p>}
    </main>
  )
}

