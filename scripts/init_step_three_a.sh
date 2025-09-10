#!/usr/bin/env bash
# zsh guard
if [ -n "${ZSH_VERSION-}" ]; then exec /usr/bin/env bash "$0" "$@"; fi
set -Eeuo pipefail
trap 'echo "❌ Error on line $LINENO: $BASH_COMMAND" >&2' ERR

die(){ echo "❌ $*" >&2; exit 1; }
note(){ echo "➜ $*"; }
ok(){ echo "✅ $*"; }

# ---- 0) strict .env loader (literal-only) ----
ENV_FILE="${ENV_FILE:-.env}"
if [ ! -f "$ENV_FILE" ] && [ -f "../.env" ]; then ENV_FILE="../.env"; fi
[ -f "$ENV_FILE" ] || die "Missing .env (set ENV_FILE or place a .env file here or one directory up)"
ENV_FILE="$(cd "$(dirname "$ENV_FILE")" && pwd)/$(basename "$ENV_FILE")"
if grep -n '\$' "$ENV_FILE" >/dev/null; then
  echo "❌ $ENV_FILE must be literal-only (no $ or ${…}). Offending lines:" >&2
  grep -n '\$' "$ENV_FILE" >&2 || true
  exit 1
fi
set -a
while IFS= read -r line; do
  [[ -z "$line" || "$line" =~ ^[[:space:]]*# ]] && continue
  if [[ ! "$line" =~ ^[[:space:]]*([A-Za-z_][A-Za-z0-9_]*)[[:space:]]*=(.*)$ ]]; then
    die "Invalid line in $ENV_FILE: $line"
  fi
  key="${BASH_REMATCH[1]}"; val="${BASH_REMATCH[2]}"
  val="${val#"${val%%[![:space:]]*}"}"
  export "$key=$val"
done < "$ENV_FILE"
set +a
ok "Loaded env from $ENV_FILE"

# ---- 1) detect frontend and backend dirs ----
detect_next_dir() {
  for d in ./frontend ./apps/frontend ./apps/web ./packages/frontend ./packages/web .; do
    if [ -f "$d/package.json" ] && grep -q '"next"' "$d/package.json"; then echo "$d"; return 0; fi
  done; return 1
}
detect_backend_dir() {
  for d in ./backend ./apps/backend ./packages/backend .; do
    if [ -f "$d/app/main.py" ]; then echo "$d"; return 0; fi
  done; return 1
}
NEXT_DIR="$(detect_next_dir)" || die "Next.js app not found"
BE_DIR="$(detect_backend_dir)" || die "FastAPI backend not found"
note "Frontend: ${NEXT_DIR} | Backend: ${BE_DIR}"

# ---- 2) ensure backend deps ----
REQ_FILE="${BE_DIR}/requirements.txt"
grep -q '^pgpy' "$REQ_FILE" || echo "pgpy==0.6.0" >> "$REQ_FILE"
ok "Backend requirements updated (pgpy)"

# ---- 3) scaffold PGP auth routes ----
PGP_ROUTE_FILE="${BE_DIR}/app/api/routes_auth_pgp.py"
if [ ! -f "$PGP_ROUTE_FILE" ]; then
  note "Adding PGP auth router…"
  mkdir -p "${BE_DIR}/app/api"
  cat > "$PGP_ROUTE_FILE" <<'PY'
from fastapi import APIRouter, HTTPException, status, Response, Header
from pydantic import BaseModel, EmailStr
from typing import Optional, Dict
from datetime import datetime, timedelta
import secrets
import os
import re

from pgpy import PGPKey, PGPMessage

router = APIRouter()

pending_registrations: Dict[str, dict] = {}
approved_users: Dict[str, dict] = {}
challenges: Dict[str, dict] = {}
bans: Dict[str, dict] = {}

def now():
    from datetime import datetime as _dt
    return _dt.utcnow()

def compute_fingerprint(pubkey_armor: str) -> str:
    key, _ = PGPKey.from_blob(pubkey_armor)
    return key.fingerprint

def key_bits(pubkey_armor: str) -> int:
    key, _ = PGPKey.from_blob(pubkey_armor)
    return key.key_size

def validate_pubkey(pubkey_armor: str) -> None:
    if "BEGIN PGP PUBLIC KEY BLOCK" not in pubkey_armor:
        raise HTTPException(status_code=400, detail="Invalid PGP public key format")
    try:
        bits = key_bits(pubkey_armor)
    except Exception:
        raise HTTPException(status_code=400, detail="Unable to parse PGP key")
    if bits < 4096:
        raise HTTPException(status_code=400, detail="PGP key must be >= 4096 bits")

class Registration(BaseModel):
    handle: str
    email: EmailStr
    public_key: str

@router.post("/auth/register")
def register(payload: Registration):
    handle = payload.handle.strip()
    if not re.match(r"^[a-zA-Z0-9_\-]{3,32}$", handle):
        raise HTTPException(status_code=400, detail="Handle must be 3-32 chars (alnum, _,-)")
    validate_pubkey(payload.public_key)
    fpr = compute_fingerprint(payload.public_key)
    rec = {"handle": handle, "email": payload.email, "public_key": payload.public_key.strip(), "fingerprint": fpr, "status": "pending", "created_at": now().isoformat()}
    pending_registrations[fpr] = rec
    return {"status": "pending", "fingerprint": fpr}

@router.post("/auth/admin/approve/{fingerprint}")
def approve(fingerprint: str, x_admin_token: Optional[str] = Header(default=None)):
    admin_token = os.getenv("ADMIN_TOKEN")
    if not admin_token or x_admin_token != admin_token:
        raise HTTPException(status_code=401, detail="Unauthorized")
    rec = pending_registrations.pop(fingerprint, None)
    if not rec:
        raise HTTPException(status_code=404, detail="Pending registration not found")
    rec["status"] = "approved"
    approved_users[fingerprint] = rec
    return {"status": "approved", "fingerprint": fingerprint}

class ChallengeRequest(BaseModel):
    public_key: str
    client_fp: str

@router.post("/auth/challenge")
def issue_challenge(payload: ChallengeRequest):
    ban = bans.get(payload.client_fp)
    if ban and now() < ban["until"]:
        raise HTTPException(status_code=429, detail="Temporarily blocked. Try later.")
    validate_pubkey(payload.public_key)
    fpr = compute_fingerprint(payload.public_key)
    user = approved_users.get(fpr)
    if not user:
        raise HTTPException(status_code=404, detail="Key not approved")
    code = f"{secrets.randbelow(10**6):06d}"
    msg = PGPMessage.new(code)
    key, _ = PGPKey.from_blob(user["public_key"])  # encrypt to stored key
    enc = key.encrypt(msg)
    challenges[payload.client_fp] = {"code": code, "issued_at": now(), "attempts": 0}
    return {"encrypted": str(enc)}

class VerifyRequest(BaseModel):
    client_fp: str
    code: str

@router.post("/auth/verify")
def verify(payload: VerifyRequest, response: Response):
    ban = bans.get(payload.client_fp)
    if ban and now() < ban["until"]:
        raise HTTPException(status_code=429, detail="Temporarily blocked. Try later.")
    ch = challenges.get(payload.client_fp)
    if not ch:
        raise HTTPException(status_code=400, detail="No active challenge")
    from datetime import timedelta
    if now() - ch["issued_at"] > timedelta(seconds=25):
        del challenges[payload.client_fp]
        raise HTTPException(status_code=400, detail="Challenge expired")
    if payload.code.strip() != ch["code"]:
        ch["attempts"] += 1
        if ch["attempts"] >= 3:
            bans[payload.client_fp] = {"until": now() + timedelta(hours=24)}
            del challenges[payload.client_fp]
            raise HTTPException(status_code=429, detail="Too many attempts. Temporarily blocked.")
        raise HTTPException(status_code=401, detail="Incorrect code")
    del challenges[payload.client_fp]
    token = "sess-" + secrets.token_urlsafe(24)
    response.set_cookie(key="session", value=token, httponly=True, samesite="lax", secure=False, max_age=60*60*12, path="/")
    return {"ok": True, "access_token": token}
PY
  ok "PGP auth router created"
else
  note "PGP auth router exists; skipping"
fi

# ---- 4) wire PGP router into FastAPI app ----
MAIN_PY="${BE_DIR}/app/main.py"
grep -q "routes_auth_pgp" "$MAIN_PY" || {
  note "Wiring PGP auth router into app/main.py"
  tmp="$(mktemp)"
  awk '
    BEGIN{added_import=0}
    /routes_auth/ && !added_import { print; print "from app.api.routes_auth_pgp import router as auth_pgp_router"; added_import=1; next }
    { print }
  ' "$MAIN_PY" > "$tmp" && mv "$tmp" "$MAIN_PY"
}
grep -q "include_router\(\s*auth_pgp_router" "$MAIN_PY" || {
  printf "\napp.include_router(auth_pgp_router, prefix=\"\")\n" >> "$MAIN_PY"
}
ok "PGP router wired"

# ---- 5) scaffold frontend: register page + auth modal ----
REG_PAGE="${NEXT_DIR}/pages/register.tsx"
if [ ! -f "$REG_PAGE" ]; then
  note "Adding /register page…"
  mkdir -p "${NEXT_DIR}/pages"
  cat > "$REG_PAGE" <<'TSX'
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
TSX
  ok "Register page created"
else
  note "Register page exists; skipping"
fi

ok "PGP auth scaffolding complete"
echo "- Set ADMIN_TOKEN in backend environment for admin approval"
echo "- Start backend: cd backend && pip install -r requirements.txt && uvicorn app.main:app --reload"
echo "- Start frontend: cd frontend && npm run dev (visit /register and Sign In modal)"
