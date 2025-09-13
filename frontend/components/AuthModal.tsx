import { useMemo, useState } from 'react'
import styles from '../styles/modal.module.scss'

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
  const base = process.env.NEXT_PUBLIC_API_BASE || 'http://localhost:8000'
  const client_fp = useMemo(() => genClientFP(), [])
  const [publicKey, setPublicKey] = useState('')
  const [encrypted, setEncrypted] = useState('')
  const [code, setCode] = useState('')
  const [stage, setStage] = useState<'input'|'challenge'|'done'>('input')
  const [error, setError] = useState<string>('')
  const [open, setOpen] = useState(true)
  const [fieldErrors, setFieldErrors] = useState<{publicKey?:string; code?:string}>({})

  const requestChallenge = async () => {
    setError('')
    const errs: typeof fieldErrors = {}
    if (!publicKey.includes('BEGIN PGP PUBLIC KEY BLOCK')) errs.publicKey = 'Paste an ASCII‑armored public key'
    setFieldErrors(errs)
    if (Object.keys(errs).length) return
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
    const errs: typeof fieldErrors = {}
    if (!/^\d{6}$/.test(code.trim())) errs.code = 'Enter the 6‑digit code'
    setFieldErrors(errs)
    if (Object.keys(errs).length) return
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

  const requestClose = () => { setOpen(false); setTimeout(onClose, 240) }
  return (
    <div className={`${styles.overlay} ${open ? styles.overlayOpen : styles.overlayClose}`}>
      <div className={`${styles.modal} ${open ? styles.modalOpen : styles.modalClose}`}>
        <div className={styles.header}>
          <h2 className={styles.title}>Sign In</h2>
          <button className={styles.closeBtn} onClick={requestClose}>Close</button>
        </div>
        {stage==='input' && (
          <div className={styles.form}>
            <label className={styles.row}>
              <span>Public PGP Key (ASCII-armor)</span>
              <textarea className={`${styles.textarea} ${fieldErrors.publicKey ? styles.textareaError : ''}`} rows={10} value={publicKey} onChange={e=>setPublicKey(e.target.value)} placeholder="-----BEGIN PGP PUBLIC KEY BLOCK-----" aria-invalid={!!fieldErrors.publicKey} />
              {fieldErrors.publicKey && <small className={styles.errorText}>{fieldErrors.publicKey}</small>}
            </label>
            <div className={styles.actions}>
              <button className="btn" onClick={requestChallenge}>Request Challenge</button>
            </div>
          </div>
        )}
        {stage==='challenge' && (
          <div className={styles.form}>
            <p>Decrypt the block below with your private key, then enter the 6-digit code.</p>
            <textarea className={styles.textarea} rows={12} value={encrypted} readOnly />
            <input className={`${styles.input} ${fieldErrors.code ? styles.inputError : ''}`} placeholder="Decrypted 6-digit code" value={code} onChange={e=>setCode(e.target.value)} aria-invalid={!!fieldErrors.code} />
            {fieldErrors.code && <small className={styles.errorText}>{fieldErrors.code}</small>}
            <div className={styles.actions}>
              <button className="btn" onClick={verifyCode}>Verify</button>
            </div>
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
