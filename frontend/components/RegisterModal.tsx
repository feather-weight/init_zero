import React, { useState } from 'react'
import styles from '../styles/modal.module.scss'

type Props = { onClose: () => void }

export default function RegisterModal({ onClose }: Props) {
  const [handle, setHandle] = useState('')
  const [email, setEmail] = useState('')
  const [publicKey, setPublicKey] = useState('')
  const [result, setResult] = useState<string>('')
  const base = process.env.NEXT_PUBLIC_API_BASE || 'http://localhost:8000'
  const [errors, setErrors] = useState<{handle?:string; email?:string; publicKey?:string}>({})
  const [open, setOpen] = useState(true)
  const [stage, setStage] = useState<'form'|'challenge'|'done'>('form')
  const [fingerprint, setFingerprint] = useState('')
  const [encrypted, setEncrypted] = useState('')
  const [code, setCode] = useState('')

  const onSubmit = async (e: React.FormEvent) => {
    e.preventDefault()
    setResult('')
    const nextErrors: typeof errors = {}
    if (!/^[A-Za-z0-9_-]{3,32}$/.test(handle)) nextErrors.handle = '3–32 chars; letters, numbers, _ or -'
    if (!/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(email)) nextErrors.email = 'Enter a valid email'
    if (!publicKey.includes('BEGIN PGP PUBLIC KEY BLOCK')) nextErrors.publicKey = 'Paste an ASCII‑armored public key'
    setErrors(nextErrors)
    if (Object.keys(nextErrors).length) return
    try {
      const res = await fetch(`${base}/auth/register`, {
        method: 'POST', headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ handle, email, public_key: publicKey })
      })
      const data = await res.json()
      if (!res.ok) throw new Error(data?.detail || 'Registration failed')
      setEncrypted(data.encrypted)
      setFingerprint(data.fingerprint)
      setStage('challenge')
      setResult('')
    } catch (e: any) {
      setResult(`Error: ${e.message || String(e)}`)
    }
  }

  const verifyRegistration = async () => {
    const errs: typeof errors = {}
    if (!/^\d{6}$/.test(code.trim())) errs.publicKey = '' // re-use
    setErrors(errs)
    try {
      const res = await fetch(`${base}/auth/register/verify`, {
        method: 'POST', headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ fingerprint, code })
      })
      const data = await res.json()
      if (!res.ok) throw new Error(data?.detail || 'Verification failed')
      if (data.email === 'sent' || data.email === 'not_configured') {
        setResult('PGP ownership verified. Check your inbox for an encrypted email verification link.')
      } else if (data.email === 'send_failed') {
        setResult('PGP verified, but email failed to send. Contact support.')
      } else {
        setResult('PGP ownership verified.')
      }
      setStage('done')
    } catch (e: any) {
      setResult(`Error: ${e.message || String(e)}`)
    }
  }

  const requestClose = () => { setOpen(false); setTimeout(onClose, 240) }
  return (
    <div className={`${styles.overlay} ${open ? styles.overlayOpen : styles.overlayClose}`}>
      <div className={`${styles.modal} ${open ? styles.modalOpen : styles.modalClose}`}>
        <div className={styles.header}>
          <h2 className={styles.title}>Register</h2>
          <button className={styles.closeBtn} onClick={requestClose}>Close</button>
        </div>
        {stage === 'form' && (
          <form className={styles.form} onSubmit={onSubmit}>
            <label className={styles.row}>
              <span>Desired handle <span className={styles.hintIcon} title="3–32 chars; letters, numbers, _ or - only">ⓘ</span></span>
              <input className={`${styles.input} ${errors.handle ? styles.inputError : ''}`} placeholder="handle" value={handle} onChange={e=>setHandle(e.target.value)} aria-invalid={!!errors.handle} />
              {errors.handle && <small className={styles.errorText}>{errors.handle}</small>}
            </label>
            <label className={styles.row}>
              <span>Verifiable email <span className={styles.hintIcon} title="We will contact and verify ownership (KYC)">ⓘ</span></span>
              <input className={`${styles.input} ${errors.email ? styles.inputError : ''}`} placeholder="you@example.com" value={email} onChange={e=>setEmail(e.target.value)} aria-invalid={!!errors.email} />
              {errors.email && <small className={styles.errorText}>{errors.email}</small>}
            </label>
            <label className={styles.row}>
              <span>Public PGP key (ASCII-armor) <span className={styles.hintIcon} title="Use a strong 4096-bit key with passphrase; do not use web key generators or weak tools.">ⓘ</span></span>
              <textarea className={`${styles.textarea} ${errors.publicKey ? styles.textareaError : ''}`} rows={14} placeholder="-----BEGIN PGP PUBLIC KEY BLOCK-----" value={publicKey} onChange={e=>setPublicKey(e.target.value)} aria-invalid={!!errors.publicKey} />
              {errors.publicKey && <small className={styles.errorText}>{errors.publicKey}</small>}
            </label>
            <div className={styles.actions}>
              <button className="btn" type="submit">Submit</button>
              {result && <span className="hint">{result}</span>}
            </div>
          </form>
        )}
        {stage === 'challenge' && (
          <div className={styles.form}>
            <p>Decrypt the block below with your private key, then enter the 6-digit code to prove ownership.</p>
            <textarea className={styles.textarea} rows={12} value={encrypted} readOnly />
            <input className={styles.input} placeholder="Decrypted 6-digit code" value={code} onChange={e=>setCode(e.target.value)} />
            <div className={styles.actions}>
              <button className="btn" type="button" onClick={verifyRegistration}>Verify Ownership</button>
            </div>
          </div>
        )}
        {stage === 'done' && (
          <div className={styles.form}>
            <p>{result || 'Ownership verified. Check your email for the encrypted verification link.'}</p>
          </div>
        )}
      </div>
    </div>
  )
}
