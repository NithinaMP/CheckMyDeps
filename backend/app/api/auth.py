from fastapi import Depends, APIRouter, Header, HTTPException
from firebase_admin import auth as firebase_auth

# This import ensures Firebase Admin is initialized
from app.database.firestore import db

router = APIRouter()


def verify_token(authorization: str = Header(...)):
    """Dependency used by protected routes to confirm the request
    carries a valid Firebase ID token."""

    if not authorization.startswith("Bearer "):
        raise HTTPException(
            status_code=401,
            detail="Missing bearer token"
        )

    token = authorization[len("Bearer "):].strip()

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