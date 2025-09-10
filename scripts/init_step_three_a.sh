#!/usr/bin/env bash
set -euo pipefail

ROOT="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
cd "$ROOT"

echo "==> Step 3: PGP auth — deps"
test -f package.json || { echo "No package.json in $PWD. Run Step 1 first."; exit 1; }

# Add server deps (no client private-key use)
npx jsr add openpgp@^6.0.0 >/dev/null 2>&1 || npm i openpgp@^6 --save
npm i mongoose@^8 cookie@^0.6 uuid@^9 --save

echo "==> Mongo lib"
mkdir -p lib app/api/auth app/(public)/components models

cat > lib/db.ts <<'TS'
import mongoose from "mongoose";
const uri = process.env.MONGODB_URI!;
if (!uri) throw new Error("MONGODB_URI not set");
let conn = globalThis.__MONGO_CONN as typeof mongoose | undefined;
export async function db() {
  if (conn) return conn;
  conn = await mongoose.connect(uri, { dbName: process.env.MONGODB_DB || "wallet_recovery" });
  (globalThis as any).__MONGO_CONN = conn;
  return conn;
}
TS

echo "==> Session util"
cat > lib/session.ts <<'TS'
import { randomUUID } from "crypto";
import { db } from "./db";
import mongoose from "mongoose";
const SessionSchema = new mongoose.Schema({
  sid: { type: String, index: true, unique: true },
  userId: String,
  role: String,
  createdAt: { type: Date, default: Date.now },
  expiresAt: { type: Date, index: true }
});
const Session = mongoose.models.Session || mongoose.model("Session", SessionSchema);
export async function createSession(userId: string, role: string, ttlSec=60*60*8) {
  await db();
  const sid = randomUUID();
  const exp = new Date(Date.now() + ttlSec*1000);
  await Session.create({ sid, userId, role, expiresAt: exp });
  return { sid, exp };
}
export async function getSession(sid?: string) {
  if (!sid) return null;
  await db();
  const s = await Session.findOne({ sid, expiresAt: { $gt: new Date() }});
  return s ? { userId: s.userId, role: s.role } : null;
}
export async function destroySession(sid?: string) {
  if (!sid) return;
  await db();
  await Session.deleteOne({ sid });
}
TS

echo "==> User model"
cat > models/User.ts <<'TS'
import mongoose from "mongoose";
const UserSchema = new mongoose.Schema({
  pgpPublicKey: { type: String, required: true },
  fingerprint: { type: String, index: true, unique: true },
  email: String,
  role: { type: String, enum: ["admin","user"], default: "user" },
  approved: { type: Boolean, default: false },
  failedAttempts: { type: Number, default: 0 },
  lastLogin: Date
}, { timestamps: true });
export default mongoose.models.User || mongoose.model("User", UserSchema);
TS

echo "==> Auth routes (challenge, verify, logout)"
mkdir -p app/api/auth/challenge app/api/auth/verify app/api/auth/logout

cat > app/api/auth/challenge/route.ts <<'TS'
import { NextResponse } from "next/server";
import { db } from "@/lib/db";
import User from "@/models/User";
import { cookies } from "next/headers";

function fpFromKeyArmor(armor: string) {
  // Very light fingerprint heuristic; proper parse happens at registration step.
  return armor.replace(/\s+/g,"").slice(-40).toLowerCase();
}

export async function POST(req: Request) {
  await db();
  const { identifier } = await req.json(); // fingerprint or full armored key
  if (!identifier) return NextResponse.json({ error: "Missing identifier" }, { status: 400 });
  const fingerprint = identifier.includes("BEGIN PGP PUBLIC KEY") ? fpFromKeyArmor(identifier) : String(identifier).toLowerCase();
  const user = await User.findOne({ fingerprint, approved: true });
  if (!user) return NextResponse.json({ error: "Not approved or unknown key" }, { status: 403 });

  // One-time challenge (nonce + ts)
  const challenge = `wallet-recovery-login:${crypto.randomUUID()}:${Date.now()}`;
  // Store challenge in a httpOnly cookie (short-lived) namespaced per user fingerprint
  const cookieName = `chal_${fingerprint}`;
  const res = NextResponse.json({ challenge });
  res.cookies.set(cookieName, challenge, { httpOnly: true, maxAge: 300, sameSite: "lax", path: "/" });
  return res;
}
TS

cat > app/api/auth/verify/route.ts <<'TS'
import { NextResponse } from "next/server";
import { db } from "@/lib/db";
import User from "@/models/User";
import { cookies } from "next/headers";
import * as openpgp from "openpgp";
import { createSession } from "@/lib/session";

function cookieNameFor(fp: string) { return `chal_${fp}`; }

export async function POST(req: Request) {
  await db();
  const { fingerprint, signature } = await req.json();
  if (!fingerprint || !signature) return NextResponse.json({ error: "Missing fields" }, { status: 400 });

  const user = await User.findOne({ fingerprint: String(fingerprint).toLowerCase(), approved: true });
  if (!user) return NextResponse.json({ error: "Unknown or unapproved" }, { status: 403 });

  const cookieName = cookieNameFor(user.fingerprint);
  const chal = cookies().get(cookieName)?.value;
  if (!chal) return NextResponse.json({ error: "Challenge missing/expired" }, { status: 400 });

  try {
    const pubkey = await openpgp.readKey({ armoredKey: user.pgpPublicKey });
    const sig = await openpgp.readSignature({ armoredSignature: signature });
    const msg = await openpgp.createMessage({ text: chal });
    const v = await openpgp.verify({ message: msg, signature: sig, verificationKeys: pubkey });
    const verified = await v.signatures[0].verified;
    await verified; // throws if bad

    user.failedAttempts = 0;
    user.lastLogin = new Date();
    await user.save();

    const { sid, exp } = await createSession(String(user._id), user.role);
    const res = NextResponse.json({ ok: true, role: user.role });
    res.cookies.set("sid", sid, { httpOnly: true, sameSite: "lax", path: "/", expires: exp });
    res.cookies.set(cookieName, "", { maxAge: 0, path: "/" }); // clear challenge
    return res;
  } catch (e) {
    user.failedAttempts = (user.failedAttempts ?? 0) + 1;
    await user.save();
    const locked = user.failedAttempts >= 3;
    return NextResponse.json({ error: locked ? "Account locked" : "Invalid signature" }, { status: locked ? 423 : 401 });
  }
}
TS

cat > app/api/auth/logout/route.ts <<'TS'
import { NextResponse } from "next/server";
import { destroySession } from "@/lib/session";
import { cookies } from "next/headers";

export async function POST() {
  const sid = cookies().get("sid")?.value;
  await destroySession(sid);
  const res = NextResponse.json({ ok: true });
  res.cookies.set("sid","",{ maxAge:0, path:"/"});
  return res;
}
TS

echo "==> Login modal component"
mkdir -p app/(public)/components
cat > app/(public)/components/LoginModal.tsx <<'TSX'
"use client";
import { useState } from "react";

export default function LoginModal() {
  const [open, setOpen] = useState(false);
  const [key, setKey] = useState("");
  const [challenge, setChallenge] = useState("");
  const [signature, setSignature] = useState("");
  const [step, setStep] = useState<"key"|"sign"|"done">("key");
  const [error, setError] = useState("");

  async function getChallenge() {
    setError("");
    const r = await fetch("/api/auth/challenge", { method:"POST", headers:{ "Content-Type":"application/json" }, body: JSON.stringify({ identifier: key })});
    const j = await r.json();
    if (!r.ok) return setError(j.error || "Failed to get challenge");
    setChallenge(j.challenge);
    setStep("sign");
  }

  async function verify() {
    setError("");
    const fp = key.includes("BEGIN PGP") ? key.replace(/\s+/g,"").slice(-40).toLowerCase() : key.toLowerCase();
    const r = await fetch("/api/auth/verify", { method:"POST", headers:{ "Content-Type":"application/json" }, body: JSON.stringify({ fingerprint: fp, signature })});
    const j = await r.json();
    if (!r.ok) return setError(j.error || "Verify failed");
    setStep("done");
    setTimeout(()=>location.reload(), 750);
  }

  if (!open) return <button onClick={()=>setOpen(true)} className="rounded-xl px-4 py-2 border">Login</button>;
  return (
    <div className="fixed inset-0 bg-black/50 flex items-center justify-center p-4">
      <div className="bg-white rounded-2xl p-6 w-full max-w-xl space-y-4">
        <h2 className="text-xl font-semibold">PGP Login</h2>
        {step==="key" && <>
          <textarea value={key} onChange={e=>setKey(e.target.value)} placeholder="Paste your ASCII-armored PGP public key or fingerprint" className="w-full h-32 border rounded p-2"/>
          <button onClick={getChallenge} className="rounded px-3 py-2 border">Get Challenge</button>
        </>}
        {step==="sign" && <>
          <p className="text-sm">Copy the challenge, sign it locally (e.g. <code>gpg --armor --detach-sign</code>), then paste the signature.</p>
          <textarea readOnly value={challenge} className="w-full h-24 border rounded p-2"/>
          <textarea value={signature} onChange={e=>setSignature(e.target.value)} placeholder="Paste detached signature (-----BEGIN PGP SIGNATURE-----)" className="w-full h-32 border rounded p-2"/>
          <div className="flex gap-2">
            <button onClick={()=>navigator.clipboard.writeText(challenge)} className="rounded px-3 py-2 border">Copy</button>
            <button onClick={verify} className="rounded px-3 py-2 border">Verify</button>
          </div>
        </>}
        {step==="done" && <p className="text-green-700">Authenticated. Reloading…</p>}
        {error && <p className="text-red-600 text-sm">{error}</p>}
        <button onClick={()=>setOpen(false)} className="absolute top-2 right-3">✕</button>
      </div>
    </div>
  );
}
TSX

echo "==> Wire modal into home"
# Adds modal import + button into app/page.tsx if present
if [ -f app/page.tsx ]; then
  grep -q "LoginModal" app/page.tsx || cat >> app/page.tsx <<'TSX'

import dynamic from "next/dynamic";
const LoginModal = dynamic(()=>import("./(public)/components/LoginModal"), { ssr:false });

export default function Page() {
  return (
    <main className="min-h-dvh flex items-center justify-center">
      <div className="space-y-4 text-center">
        <h1 className="text-3xl font-bold">Wallet Recovery</h1>
        <LoginModal />
      </div>
    </main>
  );
}
TSX
fi

echo "==> Seed admin helper"
mkdir -p scripts
cat > scripts/seed_admin_user.js <<'JS'
import { db } from "../lib/db.js";
import User from "../models/User.js";
import crypto from "crypto";

// Usage: node scripts/seed_admin_user.js "<ARMOR_PUBKEY>"
const armor = process.argv[2];
if (!armor) { console.error("Provide ASCII-armored public key as arg"); process.exit(1); }
function fp(a){ return a.replace(/\s+/g,"").slice(-40).toLowerCase(); }

const run = async () => {
  await db();
  const fingerprint = fp(armor);
  const existing = await User.findOne({ fingerprint });
  if (existing) { existing.pgpPublicKey = armor; existing.role="admin"; existing.approved=true; await existing.save(); console.log("Updated existing admin", fingerprint); process.exit(0); }
  await User.create({ pgpPublicKey: armor, fingerprint, role:"admin", approved:true });
  console.log("Seeded admin:", fingerprint);
  process.exit(0);
};
run();
JS

echo "==> Env check + build"
grep -q "MONGODB_URI" .env || echo 'MONGODB_URI=mongodb://localhost:27017' >> .env
npm run build
echo "Step 3 scaffolding complete."

