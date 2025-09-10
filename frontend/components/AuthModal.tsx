import { useEffect, useMemo, useState } from 'react'

type Props = { onClose: () => void }

function genClientFP(): string {
  // Simple client fingerprint persisted locally
  if (typeof window === 'undefined') return 'server'
  const k = 'client_fp'
  let fp = localStorage.getItem(k)
  if (!fp) {
    const ua = navigator.userAgent
    const tz = Intl.DateTimeFormat().resolvedOptions().timeZone || ''
    fp = btoa(`${ua}|${tz}|${Math.random().toString(36).slice(2)}`)
    localStorage.setItem(k, fp)
  }
  return fp
}

export default function AuthModal({ onClose }: Props) {
  const base = process.env.NEXT_PUBLIC_BE_URL || 'http://localhost:8000'
  const client_fp = useMemo(() => genClientFP(), [])
  const [publicKey, setPublicKey] = useState('')
  const [encrypted, setEncrypted] = useState('')
  const [code, setCode] = useState('')
  const [stage, setStage] = useState<'input'|'challenge'|'done'>('input')
  const [error, setError] = useState<string>('')

  const requestChallenge = async () => {
    setError('')
    try {
      const res = await fetch(`${base}/auth/challenge`, {
        method: 'POST', headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ public_key: publicKey, client_fp })
      })
      const data = await res.json()
      if (!res.ok) throw new Error(data?.detail || 'Challenge failed')
      setEncrypted(data.encrypted)
      setStage('challenge')
    } catch (e: any) { setError(e.message || String(e)) }
  }

  const verifyCode = async () => {
    setError('')
    try {
      const res = await fetch(`${base}/auth/verify`, {
        method: 'POST', headers: { 'Content-Type': 'application/json' },
        credentials: 'include',
        body: JSON.stringify({ client_fp, code })
      })
      const data = await res.json()
      if (!res.ok) throw new Error(data?.detail || 'Verify failed')
      setStage('done')
    } catch (e: any) { setError(e.message || String(e)) }
  }

  return (
    <div style={{position:'fixed', inset:0, background:'rgba(0,0,0,.6)', display:'grid', placeItems:'center', zIndex: 10}}>
      <div style={{background:'#111826aa', border:'1px solid #2a2a2a', padding:'1rem', maxWidth:680, width:'92%', borderRadius:8}}>
        <div style={{display:'flex', alignItems:'center'}}>
          <h2 style={{margin:'0 0 .5rem 0'}}>Sign In</h2>
          <button onClick={onClose} style={{marginLeft:'auto'}}>Close</button>
        </div>
        {stage==='input' && (
          <div style={{display:'grid', gap:'.5rem'}}>
            <label>Public PGP Key (ASCII-armor)
              <textarea rows={6} value={publicKey} onChange={e=>setPublicKey(e.target.value)} placeholder="-----BEGIN PGP PUBLIC KEY BLOCK-----" />
            </label>
            <button className="btn" onClick={requestChallenge}>Request Challenge</button>
          </div>
        )}
        {stage==='challenge' && (
          <div style={{display:'grid', gap:'.5rem'}}>
            <p>Decrypt the block below with your private key, then enter the 6-digit code.</p>
            <textarea rows={10} value={encrypted} readOnly />
            <input placeholder="Decrypted 6-digit code" value={code} onChange={e=>setCode(e.target.value)} />
            <button className="btn" onClick={verifyCode}>Verify</button>
          </div>
        )}
        {stage==='done' && (
          <p>Signed in. Redirecting…</p>
        )}
        {error && <p className="hint" style={{color:'#ffb4b4'}}>Error: {error}</p>}
      </div>
    </div>
  )
}

