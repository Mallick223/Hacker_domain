"""SOS dispatch worker; run with ``python -m app.sos_worker``."""

import json
import time

import redis

from . import models, sos_queue
from .database import SessionLocal


def _send_notifications(user: models.User, alert: models.SosAlert) -> None:
    """Replace this stub with real webhook, SMS, or FCM integrations."""
    print(
        f"[SOS DISPATCH] User {user.name} ({user.phone}) triggered SOS at "
        f"({alert.lat}, {alert.lng}). Emergency contact: {user.emergency_contact}. "
        f"Message: {alert.message}"
    )


def attempt_dispatch(alert_id: int, attempt_number: int, inline_fallback: bool = False) -> None:
    """Attempt one dispatch and persist the outcome for the admin audit log."""
    db = SessionLocal()
    try:
        alert = db.query(models.SosAlert).filter(models.SosAlert.id == alert_id).first()
        if not alert:
            return

        user = db.query(models.User).filter(models.User.id == alert.user_id).first()
        try:
            if user is None:
                raise LookupError(f"User {alert.user_id} for SOS alert {alert_id} was not found")
            _send_notifications(user, alert)
            db.add(models.SosDispatchAttempt(
                alert_id=alert_id,
                attempt_number=attempt_number,
                status=models.DispatchStatus.success,
            ))
            db.commit()
        except Exception as exc:  # Any downstream failure should be audited and retried.
            error_text = str(exc)
            if attempt_number >= sos_queue.MAX_ATTEMPTS:
                db.add(models.SosDispatchAttempt(
                    alert_id=alert_id,
                    attempt_number=attempt_number,
                    status=models.DispatchStatus.dead_letter,
                    error=error_text,
                ))
                db.commit()
                try:
                    sos_queue.send_to_dead_letter(alert_id, error_text)
                except redis.exceptions.RedisError as redis_error:
                    print(f"[SOS DISPATCH] Could not write dead-letter entry: {redis_error}")
                print(f"[SOS DISPATCH] alert {alert_id} exhausted retries: {error_text}")
            else:
                db.add(models.SosDispatchAttempt(
                    alert_id=alert_id,
                    attempt_number=attempt_number,
                    status=models.DispatchStatus.retrying,
                    error=error_text,
                ))
                db.commit()
                if inline_fallback:
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
