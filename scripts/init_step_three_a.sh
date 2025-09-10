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

# ---- 2) scaffold FastAPI auth routes (dev token) ----
AUTH_ROUTE_FILE="${BE_DIR}/app/api/routes_auth.py"
if [ ! -f "$AUTH_ROUTE_FILE" ]; then
  note "Adding backend auth router…"
  mkdir -p "${BE_DIR}/app/api"
  cat > "$AUTH_ROUTE_FILE" <<'PY'
from fastapi import APIRouter, Response, HTTPException, status
from pydantic import BaseModel
import secrets

router = APIRouter()

class LoginRequest(BaseModel):
    username: str
    password: str

class TokenResponse(BaseModel):
    access_token: str
    token_type: str = "bearer"

@router.post("/auth/login", response_model=TokenResponse)
def login(payload: LoginRequest, response: Response):
    # DEV-ONLY: accept any non-empty credentials and mint a pseudo token
    if not payload.username or not payload.password:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="Missing credentials")
    token = "dev-" + secrets.token_urlsafe(24)
    # Optionally set cookie (Lax for localhost dev)
    response.set_cookie(
        key="access_token",
        value=token,
        httponly=True,
        samesite="lax",
        secure=False,
        max_age=60*60*24,
        path="/",
    )
    return {"access_token": token, "token_type": "bearer"}

@router.get("/auth/me")
def me():
    # DEV-ONLY placeholder
    return {"user": {"id": "dev", "name": "Dev User"}}
PY
  ok "Auth router created: app/api/routes_auth.py"
else
  note "Auth router exists; skipping create"
fi

# ---- 3) wire router into FastAPI app ----
MAIN_PY="${BE_DIR}/app/main.py"
grep -q "routes_auth" "$MAIN_PY" || {
  note "Wiring auth router into app/main.py"
  tmp="$(mktemp)"
  awk '
    BEGIN{added_import=0}
    /routes_health/ && !added_import { print; print "from app.api.routes_auth import router as auth_router"; added_import=1; next }
    { print }
  ' "$MAIN_PY" > "$tmp" && mv "$tmp" "$MAIN_PY"
}
grep -q "include_router(\s*auth_router" "$MAIN_PY" || {
  printf "\napp.include_router(auth_router, prefix=\"\")\n" >> "$MAIN_PY"
}
ok "Auth router wired"

# ---- 4) scaffold Next.js login page ----
LOGIN_PAGE="${NEXT_DIR}/pages/login.tsx"
if [ ! -f "$LOGIN_PAGE" ]; then
  note "Adding /login page…"
  mkdir -p "${NEXT_DIR}/pages"
  cat > "$LOGIN_PAGE" <<'TSX'
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
TSX
  ok "Login page created"
else
  note "Login page exists; skipping"
fi

# ---- 5) add header Login link ----
APP_FILE="${NEXT_DIR}/pages/_app.tsx"
if [ -f "$APP_FILE" ] && ! grep -q "href=\"/login\"" "$APP_FILE"; then
  note "Adding Login link to header"
  tmp="$(mktemp)"
  awk '
    /ThemeToggle/ && seen_header==0 { print; next }
    /<div className=\"header\"/ && seen_header==0 {
      print; seen_header=1; next
    }
    seen_header==1 && /<div style=\"{ marginLeft: \'auto\' }\"><ThemeToggle \/><\/div>/ {
      print;
      print "      <a href=\"/login\" className=\"btn\" style=\"margin-left: .75rem\">Login<\/a>";
      seen_header=2; next
    }
    { print }
  ' "$APP_FILE" > "$tmp" && mv "$tmp" "$APP_FILE"
  ok "Header link added"
else
  note "Header already has Login link or _app.tsx missing; skipping"
fi

note "Auth scaffolding complete. Next steps:"
echo "- Start backend: cd backend && uvicorn app.main:app --reload"
echo "- Start frontend: cd frontend && npm run dev (visit /login)"
echo "- Configure .env: set NEXT_PUBLIC_BE_URL (e.g., http://localhost:8000)"

