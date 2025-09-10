import { useState } from 'react'

export default function Login() {
  const [username, setUsername] = useState('')
  const [password, setPassword] = useState('')
  const [result, setResult] = useState<string>('')
  const base = process.env.NEXT_PUBLIC_BE_URL || 'http://localhost:8000'

  const onSubmit = async (e: React.FormEvent) => {
    e.preventDefault()
    setResult('')
    try {
      const res = await fetch(`${base}/auth/login`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        credentials: 'include',
        body: JSON.stringify({ username, password })
      })
      const data = await res.json()
      if (!res.ok) throw new Error(data?.detail || 'Login failed')
      if (data?.access_token) localStorage.setItem('access_token', data.access_token)
      setResult('Login OK')
    } catch (err: any) {
      setResult(`Error: ${err.message || String(err)}`)
    }
  }

  return (
    <main className="container" style={{paddingBottom:'3rem'}}>
      <h1>Login</h1>
      <form onSubmit={onSubmit} style={{display:'grid', gap: '.75rem', maxWidth: 360}}>
        <input placeholder="Username" value={username} onChange={e=>setUsername(e.target.value)} />
        <input placeholder="Password" type="password" value={password} onChange={e=>setPassword(e.target.value)} />
        <button className="btn" type="submit">Sign in</button>
      </form>
      {result && <p className="hint">{result}</p>}
    </main>
  )
}

