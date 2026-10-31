"""Redis-backed queue for asynchronous SOS dispatch."""

import json
import time

import redis

from .config import settings

QUEUE_KEY = "sos:dispatch:queue"
RETRY_ZSET_KEY = "sos:dispatch:retry"
DEAD_LETTER_KEY = "sos:dispatch:deadletter"

MAX_ATTEMPTS = 5
BASE_BACKOFF_SECONDS = 10
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
    """Enqueue dispatch work, falling back inline if Redis is unavailable."""
    job = json.dumps({"alert_id": alert_id, "attempt_number": 1})
    try:
        get_redis().lpush(QUEUE_KEY, job)
    except redis.exceptions.RedisError:
        from .sos_worker import attempt_dispatch

        attempt_dispatch(alert_id, attempt_number=1, inline_fallback=True)


def schedule_retry(alert_id: int, attempt_number: int) -> None:
    ready_at = time.time() + _backoff_for(attempt_number)
    job = json.dumps({"alert_id": alert_id, "attempt_number": attempt_number + 1})
    get_redis().zadd(RETRY_ZSET_KEY, {job: ready_at})


def promote_ready_retries() -> int:
    r = get_redis()
    ready_jobs = r.zrangebyscore(RETRY_ZSET_KEY, min=0, max=time.time())
    for job in ready_jobs:
        r.zrem(RETRY_ZSET_KEY, job)
        r.lpush(QUEUE_KEY, job)
    return len(ready_jobs)


def send_to_dead_letter(alert_id: int, error: str) -> None:
    get_redis().lpush(
        DEAD_LETTER_KEY,
        json.dumps({"alert_id": alert_id, "error": error, "at": time.time()}),
    )
