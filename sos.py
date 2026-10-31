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

    # ---- Decision & Alert Engine hook ----
    # Was: a synchronous _dispatch_alert() call that just printed and
    # returned — a slow or failing notification call would have blocked
    # this request, with no record kept if it failed.
    #
    # Now: enqueue_dispatch() is a fast, non-blocking Redis push. The
    # actual fan-out (authorities/rescue, family, emergency services)
    # happens in sos_worker.py with retries + an audit trail
    # (SosDispatchAttempt), so this endpoint still returns immediately
    # and a failed dispatch is never silently lost. If Redis itself is
    # down, enqueue_dispatch falls back to an inline attempt rather than
    # dropping the SOS.
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
    """Shows every dispatch attempt for an alert — success, retries, and
    any dead-letter — so the admin dashboard can surface SOS alerts whose
    notification fan-out actually failed, not just alerts marked 'open'."""
    attempts = (
        db.query(models.SosDispatchAttempt)
        .filter(models.SosDispatchAttempt.alert_id == alert_id)
        .order_by(models.SosDispatchAttempt.attempt_number)
        .all()
    )
    return [
        {
            "attempt_number": a.attempt_number,
            "status": a.status,
            "error": a.error,
            "created_at": a.created_at,
        }
        for a in attempts
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
