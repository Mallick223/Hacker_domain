# Guardian Go — Postgres migration + SOS redundancy

Your actual layout is `D:\project_major\tourist_safety_backend\backend\`
with the FastAPI package at `app\`. Here's where each file in this bundle
goes, and what to do after copying.

## File placement

| This bundle                     | Goes to (relative to `backend\`)              | Action |
|----------------------------------|------------------------------------------------|--------|
| `database.py`                    | `app\database.py`                              | **Replace** |
| `config.py`                      | `app\config.py`                                | **Replace** |
| `sos.py`                         | `app\routers\sos.py`                           | **Replace** |
| `sos_queue.py`                   | `app\sos_queue.py`                             | New file |
| `sos_worker.py`                  | `app\sos_worker.py`                            | New file |
| `sos_dispatch_model.py`          | contents **appended** to `app\models.py`       | Merge in |
| `migrate_sqlite_to_postgres.py`  | `backend\migrate_sqlite_to_postgres.py`        | New file (note: sits in `backend\`, not `app\`, so `from app...` imports work) |
| `docker-compose.yml`             | `D:\project_major\docker-compose.yml` (repo root) | New file |
| `.env.example`                   | copy to `backend\.env` and fill in             | New file |
| `alembic.ini`                    | `backend\alembic.ini`                          | New file |
| `alembic\env.py`, `alembic\script.py.mako` | `backend\alembic\...`               | New files |
| `requirements-additions.txt`     | append lines into `backend\requirements.txt` (wherever your real one lives — the `app\` copy you showed was empty, so check if there's one at `backend\` root) | Merge in |

## Setup order

```powershell
cd D:\project_major\tourist_safety_backend\backend

# 1. Add the new dependencies
#    (merge requirements-additions.txt into your real requirements.txt, then:)
pip install -r requirements.txt

# 2. Copy .env.example to .env and adjust if you changed docker-compose creds
copy .env.example .env

# 3. Start Postgres + Redis
cd D:\project_major
docker-compose up -d
cd tourist_safety_backend\backend

# 4. Create the Alembic migration that captures your current schema
#    (this generates the "initial" migration from your existing models,
#    including the new SosDispatchAttempt table once you've merged it in)
alembic revision --autogenerate -m "initial schema incl. sos_dispatch_attempts"
alembic upgrade head

# 5. Copy your existing data from the old SQLite file into Postgres
python migrate_sqlite_to_postgres.py tourist_safety.db

# 6. Start the app as usual, PLUS the new worker process (separate terminal)
uvicorn app.main:app --reload
python -m app.sos_worker
```

## Important: `main.py` no longer needs `Base.metadata.create_all`

Now that Alembic owns schema creation, remove this line from `app\main.py`:

```python
Base.metadata.create_all(bind=engine)
```

Alembic (`alembic upgrade head`) replaces it — running both isn't harmful,
but it defeats the point of having migrations at all (silent schema drift
between environments).

## What changed, in one paragraph each

**Postgres**: Both backend configurations now require `DATABASE_URL` and
reject SQLite URLs at startup. The database engines use connection pooling
(10 steady connections, 20 burst, pre-ping to avoid stale-connection errors).
SQLite remains supported only as a source for the one-off migration script.

**SOS redundancy**: the old `_dispatch_alert` stub ran inline in the
request and only printed to console — a slow or failing real integration
(Twilio, a webhook) would block the tourist's SOS request, and a failure
left no record. Now `POST /api/sos` pushes a job to Redis and returns
immediately; `sos_worker.py` (a separate process) does the actual
notification work with exponential backoff (10s → 20s → 40s → ... capped
at 5 min) across up to 5 attempts, logs every attempt to the new
`sos_dispatch_attempts` table, and pushes to a dead-letter list if all
retries fail — so a failed SOS notification is visible to the admin
dashboard (`GET /api/sos/{id}/dispatch-log`) instead of vanishing. If
Redis itself is down, `enqueue_dispatch` falls back to an inline attempt
rather than silently dropping the SOS — this was a deliberate call for the
one endpoint in your system where losing a message actually matters.

## For your academic writeup

This maps cleanly onto a "Decision & Alert Engine" diagram: SOS trigger →
queue → async fan-out with retry/dead-letter, which is a standard resilient-
dispatch pattern (similar in spirit to what SQS + Lambda DLQs do in AWS,
just self-hosted with Redis for a student project's infra budget).
