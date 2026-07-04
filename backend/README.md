# Tourist Safety Backend — FastAPI

Implements the exact API contract the Flutter app expects:
`/api/auth/register`, `/api/auth/login`, `/api/location/update`, `/api/sos`,
plus supporting endpoints for the Admin Dashboard.

Tested end-to-end (register → login → location update → SOS → admin views)
before packaging — see "What was verified" below.

## 1. Setup

```bash
cd tourist_safety_backend
python3 -m venv venv
source venv/bin/activate          # Windows: venv\Scripts\activate
pip install -r requirements.txt
```

## 2. Configure

Defaults live in `app/config.py` and can be overridden via a `.env` file:

```env
DATABASE_URL=sqlite:///./tourist_safety.db
SECRET_KEY=some-long-random-string
ACCESS_TOKEN_EXPIRE_MINUTES=10080
```

For production, point `DATABASE_URL` at Postgres, e.g.:
```
DATABASE_URL=postgresql://user:password@localhost:5432/tourist_safety
```
(Also add `psycopg2-binary` to requirements.txt if using Postgres.)

**Set a real `SECRET_KEY` before deploying** — the default is a placeholder.

## 3. Run

```bash
uvicorn app.main:app --reload --host 0.0.0.0 --port 8000
```

Interactive API docs: `http://localhost:8000/docs`

In the Flutter app's `lib/config.dart`, set:
```dart
static const String baseUrl = "http://<your-ip-or-domain>:8000/api";
```
(Use `http://10.0.2.2:8000/api` for the Android emulator talking to your host machine.)

## 4. API Reference

| Method | Endpoint                     | Auth | Purpose |
|--------|-------------------------------|------|---------|
| POST   | `/api/auth/register`          | No   | Create account, returns token + user |
| POST   | `/api/auth/login`              | No   | Returns token + user |
| GET    | `/api/auth/me`                 | Yes  | Current user's profile |
| POST   | `/api/location/update`         | Yes  | Push a GPS ping |
| GET    | `/api/location/history`        | Yes  | Your own location history |
| GET    | `/api/location/live`           | No*  | Latest position of every user (admin dashboard) |
| POST   | `/api/sos`                     | Yes  | Trigger an emergency alert |
| GET    | `/api/sos/my`                  | Yes  | Your own SOS history |
| GET    | `/api/sos/all`                 | No*  | All SOS alerts, optional `?status=open` filter (admin dashboard) |
| PATCH  | `/api/sos/{id}/status`         | No*  | Mark an alert acknowledged/resolved (admin dashboard) |

`Yes` = requires header `Authorization: Bearer <token>`.

\* **Important:** the admin endpoints (`/location/live`, `/sos/all`,
`/sos/{id}/status`) are intentionally left open in this starter so you can
build the admin dashboard against them immediately. Before production,
add an `is_admin` flag to the `User` model and protect these with a
`get_current_admin` dependency (same pattern as `get_current_user` in
`app/security.py`).

## 5. Where to plug in real integrations

- **`app/routers/sos.py` → `_dispatch_alert()`** — currently just logs to
  console. Replace with:
  - Twilio SMS/call to `user.emergency_contact`
  - A webhook/API call to a police/rescue dispatch system
  - Firebase Cloud Messaging push to nearby tourists / the user's own app
    (for the "Tourist Alerts" panel)
- **Geo-fencing / Safe Zones** — not yet implemented. Add a `Zone` model
  (polygon or center+radius) and check `LocationPing` coordinates against
  it in `location.py`'s `update_location`, firing an alert when a tourist
  enters/exits a zone.
- **AI Risk Prediction Engine** — hook in after `update_location` saves a
  ping: feed recent pings for that user into a model/heuristic and write
  a risk score back (e.g. a new `RiskScore` table), which the admin
  dashboard and Decision & Alert Engine can read.
- **Digital ID (blockchain)** — separate concern; this backend's `User`
  model already has a stable `id` you can anchor an on-chain identity to
  later without changing the mobile app's contract.

## 6. What was verified

Before delivering, this was actually run and tested (not just written):
- Server starts cleanly, `/` health check returns 200
- Register → returns token + user, 201
- Duplicate email register → 400
- Login with correct/wrong password → 200 / 401
- `/api/auth/me` with/without token → 200 / 401
- Location update while authenticated → 201, appears in `/api/location/live`
- SOS trigger → 201, dispatch stub logs the event, appears in `/api/sos/all`
- SOS status update via PATCH → 200, status changes to `resolved`

## 7. Project structure

```
tourist_safety_backend/
  app/
    main.py          # FastAPI app + router wiring + CORS
    config.py        # Settings (DB URL, JWT secret, etc.)
    database.py      # SQLAlchemy engine/session
    models.py         # User, LocationPing, SosAlert
    schemas.py        # Pydantic request/response models
    security.py        # Password hashing (bcrypt) + JWT
    routers/
      auth.py
      location.py
      sos.py
  requirements.txt
```
