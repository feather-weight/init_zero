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
    response.set_cookie(
        key="access_token",
        value=token,
        httponly=True,
        samesite="lax",
        secure=False,
        max_age=60 * 60 * 24,
        path="/",
    )
    return {"access_token": token, "token_type": "bearer"}


@router.get("/auth/me")
def me():
    # DEV-ONLY placeholder
    return {"user": {"id": "dev", "name": "Dev User"}}

