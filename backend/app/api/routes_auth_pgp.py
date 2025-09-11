from fastapi import APIRouter, HTTPException, status, Response, Header, Query
from pydantic import BaseModel, EmailStr
from typing import Optional, Dict
from datetime import datetime, timedelta
import secrets
import os
import re

from pgpy import PGPKey, PGPMessage
from app.db.mongo import get_db
from app.services.email import send_email, is_configured as email_configured

router = APIRouter()


# In-memory bans for client fingerprints (can be moved to DB later)
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
async def register(payload: Registration):
    handle = payload.handle.strip()
    if not re.match(r"^[a-zA-Z0-9_\-]{3,32}$", handle):
        raise HTTPException(status_code=400, detail="Handle must be 3-32 chars (alnum, _,-)")
    validate_pubkey(payload.public_key)

    fpr = compute_fingerprint(payload.public_key)
    db = get_db()
    # upsert the registration as pending
    doc = {
        "_id": fpr,
        "handle": handle,
        "email": str(payload.email),
        "public_key": normalize_key(payload.public_key),
        "fingerprint": fpr,
        "pgp_verified": False,
        "email_verified": False,
        "status": "pending",
        "created_at": now(),
        "updated_at": now(),
    }
    await db.registrations.update_one({"_id": fpr}, {"$set": doc}, upsert=True)

    # Create a short-lived PGP challenge
    code = f"{secrets.randbelow(10**6):06d}"
    msg = PGPMessage.new(code)
    key, _ = PGPKey.from_blob(doc["public_key"])  # encrypt to stored key
    enc = key.encrypt(msg)

    await db.challenges.update_one(
        {"fingerprint": fpr, "kind": "registration"},
        {"$set": {"code": code, "issued_at": now(), "attempts": 0, "kind": "registration"}},
        upsert=True,
    )
    return {"encrypted": str(enc), "fingerprint": fpr}


class VerifyRegistration(BaseModel):
    fingerprint: str
    code: str


@router.post("/auth/register/verify")
async def verify_registration(payload: VerifyRegistration):
    db = get_db()
    ch = await db.challenges.find_one({"fingerprint": payload.fingerprint, "kind": "registration"})
    if not ch:
        raise HTTPException(status_code=400, detail="No active challenge")
    if now() - ch["issued_at"] > timedelta(seconds=25):
        await db.challenges.delete_one({"_id": ch.get("_id")})
        raise HTTPException(status_code=400, detail="Challenge expired")
    if payload.code.strip() != ch["code"]:
        attempts = int(ch.get("attempts", 0)) + 1
        await db.challenges.update_one({"_id": ch.get("_id")}, {"$set": {"attempts": attempts}})
        raise HTTPException(status_code=401, detail="Incorrect code")

    # Mark PGP verified
    await db.registrations.update_one({"_id": payload.fingerprint}, {"$set": {"pgp_verified": True, "updated_at": now()}})
    await db.challenges.delete_one({"_id": ch.get("_id")})

    # Email verification
    token = secrets.token_urlsafe(32)
    expires = now() + timedelta(hours=24)
    await db.email_tokens.update_one(
        {"fingerprint": payload.fingerprint},
        {"$set": {"fingerprint": payload.fingerprint, "token": token, "expires": expires}},
        upsert=True,
    )

    reg = await db.registrations.find_one({"_id": payload.fingerprint})
    verify_link = os.getenv("FRONTEND_BASE_URL", "http://localhost:3000") + f"/verify-email?token={token}"
    # Encrypt email body
    msg = PGPMessage.new(f"Please open this link to verify your email: {verify_link}")
    key, _ = PGPKey.from_blob(reg["public_key"])  # encrypt to user's key
    enc_body = str(key.encrypt(msg))

    if email_configured():
        err = send_email(
            to_addr=reg["email"],
            subject="Please verify your email",
            body=enc_body,
        )
        if err:
            # Do not fail the flow if email fails; surface info
            return {"ok": True, "email": "send_failed", "error": err}
        return {"ok": True, "email": "sent"}
    else:
        # For dev, return the encrypted body so it can be tested manually
        return {"ok": True, "email": "not_configured", "encrypted": enc_body}


@router.get("/auth/verify-email")
async def verify_email(token: str = Query(...)):
    db = get_db()
    rec = await db.email_tokens.find_one({"token": token})
    if not rec:
        raise HTTPException(status_code=400, detail="Invalid token")
    if now() > rec["expires"]:
        raise HTTPException(status_code=400, detail="Token expired")
    await db.registrations.update_one({"_id": rec["fingerprint"]}, {"$set": {"email_verified": True, "updated_at": now()}})
    await db.email_tokens.delete_one({"_id": rec.get("_id")})
    return {"ok": True}


@router.post("/auth/admin/approve/{fingerprint}")
async def approve(fingerprint: str, x_admin_token: Optional[str] = Header(default=None)):
    admin_token = os.getenv("ADMIN_TOKEN")
    if not admin_token or x_admin_token != admin_token:
        raise HTTPException(status_code=401, detail="Unauthorized")
    db = get_db()
    rec = await db.registrations.find_one({"_id": fingerprint})
    if not rec:
        raise HTTPException(status_code=404, detail="Registration not found")
    await db.registrations.update_one({"_id": fingerprint}, {"$set": {"status": "approved", "updated_at": now()}})
    return {"status": "approved", "fingerprint": fingerprint}


# Existing sign-in challenge (approved users only)
class ChallengeRequest(BaseModel):
    public_key: str
    client_fp: str


@router.post("/auth/challenge")
async def issue_challenge(payload: ChallengeRequest):
    ban = bans.get(payload.client_fp)
    if ban and now() < ban["until"]:
        raise HTTPException(status_code=429, detail="Temporarily blocked. Try later.")
    validate_pubkey(payload.public_key)
    fpr = compute_fingerprint(payload.public_key)
    db = get_db()
    user = await db.registrations.find_one({"_id": fpr, "status": "approved"})
    if not user:
        raise HTTPException(status_code=404, detail="Key not approved")

    code = f"{secrets.randbelow(10**6):06d}"
    msg = PGPMessage.new(code)
    key, _ = PGPKey.from_blob(user["public_key"])  # always encrypt to stored key
    enc = key.encrypt(msg)

    await db.challenges.update_one(
        {"client_fp": payload.client_fp, "kind": "signin"},
        {"$set": {"code": code, "issued_at": now(), "attempts": 0, "kind": "signin"}},
        upsert=True,
    )
    return {"encrypted": str(enc)}


class VerifyRequest(BaseModel):
    client_fp: str
    code: str


@router.post("/auth/verify")
async def verify(payload: VerifyRequest, response: Response):
    ban = bans.get(payload.client_fp)
    if ban and now() < ban["until"]:
        raise HTTPException(status_code=429, detail="Temporarily blocked. Try later.")
    db = get_db()
    ch = await db.challenges.find_one({"client_fp": payload.client_fp, "kind": "signin"})
    if not ch:
        raise HTTPException(status_code=400, detail="No active challenge")
    if now() - ch["issued_at"] > timedelta(seconds=25):
        await db.challenges.delete_one({"_id": ch.get("_id")})
        raise HTTPException(status_code=400, detail="Challenge expired")
    if payload.code.strip() != ch["code"]:
        attempts = int(ch.get("attempts", 0)) + 1
        if attempts >= 3:
            bans[payload.client_fp] = {"until": now() + timedelta(hours=24)}
            await db.challenges.delete_one({"_id": ch.get("_id")})
            raise HTTPException(status_code=429, detail="Too many attempts. Temporarily blocked.")
        await db.challenges.update_one({"_id": ch.get("_id")}, {"$set": {"attempts": attempts}})
        raise HTTPException(status_code=401, detail="Incorrect code")

    # Success
    await db.challenges.delete_one({"_id": ch.get("_id")})
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
