"""
Authentication API routes.
"""
import uuid
from fastapi import APIRouter, HTTPException, Depends, Header
from typing import Optional
from ..models import LoginRequest, LoginResponse
from ..database import db
from ..librus.client import LibrusClient


router = APIRouter(prefix="/auth", tags=["auth"])


def get_current_user_token(authorization: Optional[str] = Header(None)) -> str:
    """Extracts bearer token from Authorization header."""
    if not authorization:
        raise HTTPException(status_code=401, detail="Brak nagłówka autoryzacji (Authorization: Bearer <token>)")
    parts = authorization.split()
    if len(parts) != 2 or parts[0].lower() != "bearer":
        raise HTTPException(status_code=401, detail="Niepoprawny format nagłówка Authorization")
    token = parts[1]
    user = db.get_user_by_token(token)
    if not user:
        raise HTTPException(status_code=401, detail="Nieprawidłowy lub wygasły token sesji")
    return token


@router.post("/login", response_model=LoginResponse)
def login(req: LoginRequest):
    """
    Verifies credentials on Synergia, generates user token and saves to database.
    """
    client = LibrusClient(req.username, req.password)
    success, msg, student_name = client.login()

    if not success:
        raise HTTPException(status_code=400, detail=msg)

    # Generate persistent token
    token = uuid.uuid4().hex
    cookies = client.get_cookies_dict()

    db.save_user(
        token=token,
        username=req.username,
        password_raw=req.password,
        student_name=student_name,
        cookies=cookies
    )

    return LoginResponse(
        success=True,
        token=token,
        student_name=student_name,
        message=msg
    )


@router.get("/status")
def check_status(token: str = Depends(get_current_user_token)):
    user = db.get_user_by_token(token)
    return {
        "status": "ok",
        "username": user["username"],
        "student_name": user["student_name"]
    }
