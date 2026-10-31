import enum
from datetime import datetime
from sqlalchemy import Column, Integer, String, DateTime, ForeignKey, Enum, Text
from sqlalchemy.orm import relationship
from .database import Base


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
