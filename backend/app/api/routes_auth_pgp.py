from fastapi import APIRouter, HTTPException, status, Response, Header
from pydantic import BaseModel, EmailStr
from typing import Optional, Dict
from datetime import datetime, timedelta
import secrets
import os
import re

from pgpy import PGPKey, PGPMessage

router = APIRouter()


# -------- In-memory dev stores (replace with Mongo in step 3b) --------
pending_registrations: Dict[str, dict] = {}
approved_users: Dict[str, dict] = {}
challenges: Dict[str, dict] = {}
bans: Dict[str, dict] = {}


def now() -> datetime:
    return datetime.utcnow()


def normalize_key(pubkey_armor: str) -> str:
    return pubkey_armor.strip()


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
    rec = {
        "handle": handle,
        "email": payload.email,
        "public_key": normalize_key(payload.public_key),
        "fingerprint": fpr,
        "status": "pending",
        "created_at": now().isoformat(),
    }
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
    # Ban check
    ban = bans.get(payload.client_fp)
    if ban and now() < ban["until"]:
        raise HTTPException(status_code=429, detail="Temporarily blocked. Try later.")

    # Lookup approved user by fingerprint
    validate_pubkey(payload.public_key)
    fpr = compute_fingerprint(payload.public_key)
    user = approved_users.get(fpr)
    if not user:
        raise HTTPException(status_code=404, detail="Key not approved")

    # Create a short-lived challenge code (6 digits)
    code = f"{secrets.randbelow(10**6):06d}"
    msg = PGPMessage.new(code)
    key, _ = PGPKey.from_blob(user["public_key"])  # always encrypt to stored key
    enc = key.encrypt(msg)

    challenges[payload.client_fp] = {
        "code": code,
        "issued_at": now(),
        "attempts": 0,
    }
    return {"encrypted": str(enc)}


class VerifyRequest(BaseModel):
    client_fp: str
    code: str


@router.post("/auth/verify")
def verify(payload: VerifyRequest, response: Response):
    # Ban check
    ban = bans.get(payload.client_fp)
    if ban and now() < ban["until"]:
        raise HTTPException(status_code=429, detail="Temporarily blocked. Try later.")

    ch = challenges.get(payload.client_fp)
    if not ch:
        raise HTTPException(status_code=400, detail="No active challenge")

    # TTL 25s
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

    # Success
    del challenges[payload.client_fp]
    token = "sess-" + secrets.token_urlsafe(24)
    response.set_cookie(
        key="session",
        value=token,
        httponly=True,
        samesite="lax",
        secure=False,
        max_age=60 * 60 * 12,
        path="/",
    )
    return {"ok": True, "access_token": token}

