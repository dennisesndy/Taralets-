import secrets
from datetime import datetime, timedelta, timezone

import bcrypt
import jwt

from app.core.config import settings

_RECOVERY_ALPHABET = "ABCDEFGHJKLMNPQRSTUVWXYZ23456789"  # walang 0/O/1/I para hindi malito


# ---------- Password hashing (bcrypt) ----------
def hash_password(password: str) -> str:
    pw = password.encode("utf-8")
    if len(pw) > 72:  # bcrypt limit
        raise ValueError("Password must be at most 72 bytes.")
    return bcrypt.hashpw(pw, bcrypt.gensalt(rounds=settings.BCRYPT_ROUNDS)).decode("utf-8")


def verify_password(password: str, hashed: str) -> bool:
    try:
        return bcrypt.checkpw(password.encode("utf-8"), hashed.encode("utf-8"))
    except ValueError:
        return False


# Ginagamit sa login kapag walang nahanap na user, para pareho ang oras ng response
DUMMY_HASH = hash_password("dummy-password-for-timing")


# ---------- Recovery key ----------
def generate_recovery_key() -> str:
    raw = "".join(secrets.choice(_RECOVERY_ALPHABET) for _ in range(16))
    return "-".join(raw[i : i + 4] for i in range(0, 16, 4))  # XXXX-XXXX-XXXX-XXXX


def normalize_recovery_key(key: str) -> str:
    return key.replace("-", "").replace(" ", "").upper()


def hash_recovery_key(key: str) -> str:
    return hash_password(normalize_recovery_key(key))


def verify_recovery_key(key: str, hashed: str) -> bool:
    return verify_password(normalize_recovery_key(key), hashed)


# ---------- JWT ----------
def create_access_token(subject: str) -> tuple[str, int]:
    expires = timedelta(minutes=settings.ACCESS_TOKEN_EXPIRE_MINUTES)
    now = datetime.now(timezone.utc)
    payload = {"sub": subject, "type": "access", "iat": now, "exp": now + expires}
    token = jwt.encode(payload, settings.JWT_SECRET_KEY, algorithm=settings.JWT_ALGORITHM)
    return token, int(expires.total_seconds())


def decode_access_token(token: str) -> dict:
    payload = jwt.decode(
        token,
        settings.JWT_SECRET_KEY,
        algorithms=[settings.JWT_ALGORITHM],
        options={"require": ["exp", "sub"]},
    )
    if payload.get("type") != "access":
        raise jwt.InvalidTokenError("Wrong token type")
    return payload