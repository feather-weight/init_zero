import os
import smtplib
from email.message import EmailMessage
from typing import Optional


def is_configured() -> bool:
    return bool(os.getenv("SMTP_HOST") and os.getenv("SMTP_FROM"))


def send_email(to_addr: str, subject: str, body: str) -> Optional[str]:
    host = os.getenv("SMTP_HOST")
    port = int(os.getenv("SMTP_PORT", "587"))
    user = os.getenv("SMTP_USER")
    password = os.getenv("SMTP_PASS")
    from_addr = os.getenv("SMTP_FROM")

    if not host or not from_addr:
        return "SMTP not configured"

    msg = EmailMessage()
    msg["Subject"] = subject
    msg["From"] = from_addr
    msg["To"] = to_addr
    msg.set_content(body)

    try:
        with smtplib.SMTP(host, port, timeout=20) as s:
            s.starttls()
            if user and password:
                s.login(user, password)
            s.send_message(msg)
        return None
    except Exception as e:
        return str(e)

