from datetime import datetime, timedelta
from typing import List
from fastapi import APIRouter, Depends
from sqlalchemy.orm import Session
from sqlalchemy import func

from .. import models, schemas, security
from ..database import get_db
from ..config import settings

router = APIRouter(prefix="/api/location", tags=["location"])


@router.post("/update", response_model=schemas.LocationOut, status_code=201)
def update_location(
    payload: schemas.LocationUpdate,
    db: Session = Depends(get_db),
    current_user: models.User = Depends(security.get_current_user),
):
    ping = models.LocationPing(
        user_id=current_user.id,
        lat=payload.lat,
        lng=payload.lng,
        speed=payload.speed,
        heading=payload.heading,
        timestamp=payload.timestamp or datetime.utcnow(),
    )
    db.add(ping)
    db.commit()
    db.refresh(ping)
    return ping


@router.get("/history", response_model=List[schemas.LocationOut])
def my_location_history(
    limit: int = 100,
    db: Session = Depends(get_db),
    current_user: models.User = Depends(security.get_current_user),
):
    return (
        db.query(models.LocationPing)
        .filter(models.LocationPing.user_id == current_user.id)
        .order_by(models.LocationPing.timestamp.desc())
        .limit(limit)
        .all()
    )


# ---------- Admin dashboard support ----------

@router.get("/live", response_model=List[schemas.LocationOut])
def all_live_locations(db: Session = Depends(get_db)):
    """Latest known position for every user — powers the admin dashboard's
    'Live Tourist Tracking' map. In production, protect this with an
    admin-only auth dependency."""
    cutoff = datetime.utcnow() - timedelta(minutes=settings.stale_location_minutes)

    subquery = (
        db.query(
            models.LocationPing.user_id,
            func.max(models.LocationPing.timestamp).label("latest_ts"),
        )
        .group_by(models.LocationPing.user_id)
        .subquery()
    )

    latest_pings = (
        db.query(models.LocationPing)
        .join(
            subquery,
            (models.LocationPing.user_id == subquery.c.user_id)
            & (models.LocationPing.timestamp == subquery.c.latest_ts),
        )
        .filter(models.LocationPing.timestamp >= cutoff)
        .all()
    )
    return latest_pings
