from datetime import datetime
from typing import List, Optional
from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session

from .. import models, schemas, security, sos_queue
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

    # Queue notification work outside this request; the worker records each
    # attempt and retries failures. If Redis is unavailable, the queue module
    # falls back to an inline attempt so the SOS is not silently dropped.
    sos_queue.enqueue_dispatch(alert.id)

    return alert


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


@router.get("/{alert_id}/dispatch-log")
def sos_dispatch_log(alert_id: int, db: Session = Depends(get_db)):
    """Return all recorded dispatch attempts for an SOS alert."""
    attempts = (
        db.query(models.SosDispatchAttempt)
        .filter(models.SosDispatchAttempt.alert_id == alert_id)
        .order_by(models.SosDispatchAttempt.attempt_number)
        .all()
    )
    return [
        {
            "attempt_number": attempt.attempt_number,
            "status": attempt.status,
            "error": attempt.error,
            "created_at": attempt.created_at,
        }
        for attempt in attempts
    ]


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
