from fastapi import Depends, APIRouter, HTTPException
from fastapi.security import HTTPBearer, HTTPAuthorizationCredentials

from firebase_admin import auth as firebase_auth

# This import ensures Firebase Admin is initialized
from app.database.firestore import db

router = APIRouter()
security = HTTPBearer()


def verify_token(
    credentials: HTTPAuthorizationCredentials = Depends(security),
):
    """Verify Firebase ID token."""

    token = credentials.credentials

    try:
        decoded = firebase_auth.verify_id_token(token)
        return decoded

    except Exception as e:
        print("Firebase token verification error:", repr(e))
        raise HTTPException(
            status_code=401,
            detail=f"Firebase token verification failed: {str(e)}"
        )


@router.get("/me")
def get_current_user(user=Depends(verify_token)):
    return {
        "uid": user["uid"],
        "email": user.get("email")
    }