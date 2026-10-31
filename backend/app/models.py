import enum
from datetime import datetime
from sqlalchemy import (
    Column, Integer, String, Float, DateTime, ForeignKey, Enum, Text
)
from sqlalchemy.orm import relationship
from .database import Base


class User(Base):
    __tablename__ = "users"

    id = Column(Integer, primary_key=True, index=True)
    firebase_uid = Column(String, unique=True, index=True, nullable=True)
    name = Column(String, nullable=False)
    email = Column(String, unique=True, index=True, nullable=False)
    phone = Column(String, nullable=False)
    hashed_password = Column(String, nullable=True)
    emergency_contact = Column(String, nullable=True)
    created_at = Column(DateTime, default=datetime.utcnow)

    locations = relationship("LocationPing", back_populates="user", cascade="all, delete-orphan")
    sos_alerts = relationship("SosAlert", back_populates="user", cascade="all, delete-orphan")


class LocationPing(Base):
    """Every location update a tourist's app sends. Enables live tracking
    and location history on the admin dashboard."""
    __tablename__ = "location_pings"

    id = Column(Integer, primary_key=True, index=True)
    user_id = Column(Integer, ForeignKey("users.id"), nullable=False, index=True)
    lat = Column(Float, nullable=False)
    lng = Column(Float, nullable=False)
    speed = Column(Float, nullable=True)
    heading = Column(Float, nullable=True)
    timestamp = Column(DateTime, default=datetime.utcnow, index=True)

    user = relationship("User", back_populates="locations")


class SosStatus(str, enum.Enum):
    open = "open"
    acknowledged = "acknowledged"
    resolved = "resolved"


class SosAlert(Base):
    """An emergency SOS event. This is what the Decision & Alert Engine
    fans out to Authorities/Rescue, Family Members, and Emergency Services."""
    __tablename__ = "sos_alerts"

    id = Column(Integer, primary_key=True, index=True)
    user_id = Column(Integer, ForeignKey("users.id"), nullable=False, index=True)
    lat = Column(Float, nullable=False)
    lng = Column(Float, nullable=False)
    message = Column(Text, nullable=True)
    status = Column(Enum(SosStatus), default=SosStatus.open, nullable=False)
    timestamp = Column(DateTime, default=datetime.utcnow, index=True)

    user = relationship("User", back_populates="sos_alerts")


class DispatchStatus(str, enum.Enum):
    pending = "pending"       # queued, not yet attempted
    success = "success"       # delivered
    retrying = "retrying"     # failed at least once, will retry
    dead_letter = "dead_letter"  # exhausted retries — needs human attention


class SosDispatchAttempt(Base):
    """
    Audit trail for SOS fan-out (authorities / family / emergency services).
    One row per attempt, so you can see exactly what was tried, when, and
    why it failed — instead of the old print()-only stub.
    """
    __tablename__ = "sos_dispatch_attempts"

    id = Column(Integer, primary_key=True, index=True)
    alert_id = Column(Integer, ForeignKey("sos_alerts.id"), nullable=False, index=True)
    attempt_number = Column(Integer, nullable=False, default=1)
    status = Column(Enum(DispatchStatus), default=DispatchStatus.pending, nullable=False, index=True)
    error = Column(Text, nullable=True)
    created_at = Column(DateTime, default=datetime.utcnow, index=True)

    alert = relationship("SosAlert")
