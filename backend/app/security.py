import os
import firebase_admin
from firebase_admin import credentials, auth as firebase_auth
from fastapi import Depends, HTTPException, status
from fastapi.security import OAuth2PasswordBearer
from sqlalchemy.orm import Session

from .database import get_db
from . import models

# tokenUrl is unused now (Firebase handles login client-side) but kept so
# FastAPI's OpenAPI docs still render an auth field in Swagger UI.
oauth2_scheme = OAuth2PasswordBearer(tokenUrl="api/auth/login", auto_error=False)

# Path to the service account JSON you downloaded from the Firebase console.
# Keep this file OUT of git (add to .gitignore).
_SERVICE_ACCOUNT_PATH = os.path.join(
    os.path.dirname(os.path.dirname(__file__)), "firebase-service-account.json"
)

if not firebase_admin._apps:
    cred = credentials.Certificate(_SERVICE_ACCOUNT_PATH)
    firebase_admin.initialize_app(cred)


def get_current_user(
    token: str = Depends(oauth2_scheme),
    db: Session = Depends(get_db),
) -> models.User:
    if token is None:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Not authenticated",
            headers={"WWW-Authenticate": "Bearer"},
        )

    try:
        decoded = firebase_auth.verify_id_token(token)
    except Exception:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Could not validate credentials",
            headers={"WWW-Authenticate": "Bearer"},
        )

    uid = decoded.get("uid")
    email = decoded.get("email", "")
    name = decoded.get("name", "")
    if not uid or not email:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Firebase account must include a UID and email address",
        )

    user = db.query(models.User).filter(models.User.firebase_uid == uid).first()
    if user is None:
        user = db.query(models.User).filter(models.User.email == email).first()
        if user is not None:
            if not decoded.get("email_verified", False):
                raise HTTPException(
                    status_code=status.HTTP_409_CONFLICT,
                    detail="Verify your Firebase email before linking this existing account.",
                )
            user.firebase_uid = uid
            db.commit()
            db.refresh(user)
            return user

        user = models.User(
            firebase_uid=uid,
            name=name or (email.split("@")[0] if email else "Unknown"),
            email=email,
            phone="",
            hashed_password=None,
        )
        db.add(user)
        db.commit()
        db.refresh(user)

    return user