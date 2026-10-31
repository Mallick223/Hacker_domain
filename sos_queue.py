"""
SOS dispatch queue.

Why this exists: the old `_dispatch_alert` stub ran synchronously inside the
POST /api/sos request and just printed to the console — if a real Twilio/
webhook call were slow or failed there, the tourist's SOS request would hang
or silently lose the notification with no record of it.

Now:
  - `enqueue_dispatch` is called from the SOS endpoint. It's a single fast
    Redis push, so the endpoint still returns immediately to the tourist.
  - The actual notification work happens in sos_worker.py, out of the
    request path, with retries and a durable audit trail
    (SosDispatchAttempt) so a failed dispatch is never just lost.
  - If Redis itself is down, enqueue_dispatch falls back to calling the
    dispatch function directly and inline — SOS delivery must never
    silently no-op just because the queue is unavailable.
"""

import json
import time
import redis

from .config import settings

QUEUE_KEY = "sos:dispatch:queue"          # main work queue (Redis list)
RETRY_ZSET_KEY = "sos:dispatch:retry"     # delayed retries (Redis sorted set, score = ready_at unix ts)
DEAD_LETTER_KEY = "sos:dispatch:deadletter"  # for an admin-facing "needs attention" feed

MAX_ATTEMPTS = 5
BASE_BACKOFF_SECONDS = 10  # attempt 1 -> 10s, attempt 2 -> 20s, attempt 3 -> 40s ... capped below
MAX_BACKOFF_SECONDS = 300

_redis_client = None


def get_redis():
    global _redis_client
    if _redis_client is None:
        _redis_client = redis.from_url(settings.redis_url, decode_responses=True)
    return _redis_client


def _backoff_for(attempt_number: int) -> int:
    return min(BASE_BACKOFF_SECONDS * (2 ** (attempt_number - 1)), MAX_BACKOFF_SECONDS)


def enqueue_dispatch(alert_id: int) -> None:
    """Called from the SOS endpoint right after commit. Must be fast and
    must never let a queue outage swallow an SOS silently."""
    job = json.dumps({"alert_id": alert_id, "attempt_number": 1})
    try:
        get_redis().lpush(QUEUE_KEY, job)
    except redis.exceptions.RedisError:
        # Redis is unreachable — don't drop the SOS. Fall back to an
        # inline, synchronous dispatch attempt so the notification still
        # goes out even though this request now takes the hit.
        from .sos_worker import attempt_dispatch  # local import avoids a circular import at module load
        attempt_dispatch(alert_id, attempt_number=1, inline_fallback=True)


def schedule_retry(alert_id: int, attempt_number: int) -> None:
    """Puts a failed job on the delayed-retry sorted set instead of
    retrying immediately, so a flaky downstream service gets backoff
    instead of being hammered."""
    ready_at = time.time() + _backoff_for(attempt_number)
    job = json.dumps({"alert_id": alert_id, "attempt_number": attempt_number + 1})
    get_redis().zadd(RETRY_ZSET_KEY, {job: ready_at})


def promote_ready_retries() -> int:
    """Moves any retry jobs whose backoff has elapsed back onto the main
    queue. Call this periodically (the worker's scheduler loop) —
    e.g. every few seconds."""
    r = get_redis()
    now = time.time()
    ready_jobs = r.zrangebyscore(RETRY_ZSET_KEY, min=0, max=now)
    for job in ready_jobs:
        r.zrem(RETRY_ZSET_KEY, job)
        r.lpush(QUEUE_KEY, job)
    return len(ready_jobs)


def send_to_dead_letter(alert_id: int, error: str) -> None:
    """Retries exhausted. Record it for an admin feed / alerting hook."""
    get_redis().lpush(
        DEAD_LETTER_KEY,
        json.dumps({"alert_id": alert_id, "error": error, "at": time.time()}),
    )
