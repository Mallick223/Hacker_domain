"""
SOS dispatch worker.

Run this as a separate long-lived process alongside the FastAPI app:

    python -m app.sos_worker

It does two things in a loop:
  1. Promotes any delayed retries whose backoff has elapsed back onto
     the main queue (sos_queue.promote_ready_retries).
  2. Blocks on the main queue for a job, attempts dispatch, and either
     records success, schedules a backed-off retry, or sends to the
     dead-letter feed once MAX_ATTEMPTS is exhausted.

Replace the body of `_send_notifications` with your real Twilio/webhook/
FCM calls — everything else (retry, backoff, audit trail) stays the same.
"""

import json
import time
import redis

from .database import SessionLocal
from . import models  # SosDispatchAttempt / DispatchStatus live here — see README
from . import sos_queue


def _send_notifications(user: models.User, alert: models.SosAlert) -> None:
    """
    Replace this with real integrations:
      - Authorities/Rescue: POST to a dispatch webhook
      - Family: Twilio SMS to user.emergency_contact
      - Emergency services: geo-lookup nearest responder, notify

    Raise an exception on failure — the worker's retry logic depends on it.
    """
    print(
        f"[SOS DISPATCH] User {user.name} ({user.phone}) triggered SOS at "
        f"({alert.lat}, {alert.lng}). Emergency contact: {user.emergency_contact}. "
        f"Message: {alert.message}"
    )
    # e.g.: requests.post(WEBHOOK_URL, json={...}, timeout=5).raise_for_status()


def attempt_dispatch(alert_id: int, attempt_number: int, inline_fallback: bool = False) -> None:
    """Does one dispatch attempt and records the outcome. Shared by both
    the worker loop and the inline fallback path (when Redis is down)."""
    db = SessionLocal()
    try:
        alert = db.query(models.SosAlert).filter(models.SosAlert.id == alert_id).first()
        if not alert:
            return  # alert was deleted or id was bad — nothing to do

        user = db.query(models.User).filter(models.User.id == alert.user_id).first()

        try:
            _send_notifications(user, alert)
            db.add(models.SosDispatchAttempt(
                alert_id=alert_id,
                attempt_number=attempt_number,
                status=models.DispatchStatus.success,
            ))
            db.commit()

        except Exception as exc:  # noqa: BLE001 — deliberately broad: any failure should retry
            error_text = str(exc)

            if attempt_number >= sos_queue.MAX_ATTEMPTS:
                db.add(models.SosDispatchAttempt(
                    alert_id=alert_id,
                    attempt_number=attempt_number,
                    status=models.DispatchStatus.dead_letter,
                    error=error_text,
                ))
                db.commit()
                sos_queue.send_to_dead_letter(alert_id, error_text)
                print(f"[SOS DISPATCH] alert {alert_id} dead-lettered after {attempt_number} attempts: {error_text}")
            else:
                db.add(models.SosDispatchAttempt(
                    alert_id=alert_id,
                    attempt_number=attempt_number,
                    status=models.DispatchStatus.retrying,
                    error=error_text,
                ))
                db.commit()

                if inline_fallback:
                    # Redis was down when this was enqueued — retry inline
                    # with a simple sleep/backoff rather than via the queue.
                    time.sleep(sos_queue._backoff_for(attempt_number))
                    attempt_dispatch(alert_id, attempt_number + 1, inline_fallback=True)
                else:
                    sos_queue.schedule_retry(alert_id, attempt_number)
    finally:
        db.close()


def run_worker() -> None:
    r = sos_queue.get_redis()
    print("SOS dispatch worker started.")
    while True:
        try:
            promoted = sos_queue.promote_ready_retries()
            if promoted:
                print(f"Promoted {promoted} retry job(s) back onto the main queue.")

            # Blocks up to 5s waiting for a job, then loops back to check retries again.
            result = r.blpop(sos_queue.QUEUE_KEY, timeout=5)
            if result is None:
                continue

            _, raw_job = result
            job = json.loads(raw_job)
            attempt_dispatch(job["alert_id"], job["attempt_number"])

        except redis.exceptions.RedisError as exc:
            print(f"[SOS WORKER] Redis error, retrying in 5s: {exc}")
            time.sleep(5)
        except KeyboardInterrupt:
            print("SOS dispatch worker stopped.")
            break


if __name__ == "__main__":
    run_worker()
