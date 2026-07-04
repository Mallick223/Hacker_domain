from datetime import datetime
from typing import List, Optional
from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session

from .. import models, schemas, security
from ..database import get_db

router = APIRouter(prefix="/api/sos", tags=["sos"])


@router.post("", response_model=schemas.SosOut, status_code=201)
def trigger_sos(
    payload: schemas.SosCreate,
    db: Session = Depends(get_db),
    current_user: models.User = Depends(security.get_current_user),
):
    alert = models.SosAlert(
        user_id=current_user.id,
        lat=payload.lat,
        lng=payload.lng,
        message=payload.message or "Emergency SOS triggered by user",
        timestamp=payload.timestamp or datetime.utcnow(),
    )
    db.add(alert)
    db.commit()
    db.refresh(alert)

    # ---- Decision & Alert Engine hook ----
    # This is where you'd fan the alert out to:
    #   - Authorities/Rescue (e.g. push to a police dispatch API / webhook)
    #   - Family members (e.g. SMS via Twilio to current_user.emergency_contact)
    #   - Emergency services (e.g. notify nearest responder by geo-lookup)
    # Kept as a stub so you can plug in real integrations without
    # changing the request/response contract the mobile app relies on.
    _dispatch_alert(current_user, alert)

    return alert


def _dispatch_alert(user: models.User, alert: models.SosAlert) -> None:
    """Stub for fanning the SOS out to authorities / family / emergency
    services. Replace the print with real Twilio/webhook/FCM calls."""
    print(
        f"[SOS DISPATCH] User {user.name} ({user.phone}) triggered SOS at "
        f"({alert.lat}, {alert.lng}). Emergency contact: {user.emergency_contact}. "
        f"Message: {alert.message}"
    )


@router.get("/my", response_model=List[schemas.SosOut])
def my_sos_alerts(
    db: Session = Depends(get_db),
    current_user: models.User = Depends(security.get_current_user),
):
    return (
        db.query(models.SosAlert)
        .filter(models.SosAlert.user_id == current_user.id)
        .order_by(models.SosAlert.timestamp.desc())
        .all()
    )


# ---------- Admin dashboard support ----------

@router.get("/all", response_model=List[schemas.SosOut])
def all_sos_alerts(
    status: Optional[models.SosStatus] = None,
    db: Session = Depends(get_db),
):
    """Feeds the admin dashboard's Incident Monitoring panel.
    In production, protect this with an admin-only auth dependency."""
    query = db.query(models.SosAlert).order_by(models.SosAlert.timestamp.desc())
    if status:
        query = query.filter(models.SosAlert.status == status)
    return query.all()


@router.patch("/{alert_id}/status", response_model=schemas.SosOut)
def update_sos_status(
    alert_id: int,
    payload: schemas.SosStatusUpdate,
    db: Session = Depends(get_db),
):
    """Lets the admin dashboard mark an alert acknowledged/resolved."""
    alert = db.query(models.SosAlert).filter(models.SosAlert.id == alert_id).first()
    if not alert:
        raise HTTPException(status_code=404, detail="SOS alert not found")
    alert.status = payload.status
    db.commit()
    db.refresh(alert)
    return alert
