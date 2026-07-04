from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware

from .database import Base, engine
from .routers import auth, location, sos

# Creates tables on startup if they don't exist yet.
# For production, use Alembic migrations instead.
Base.metadata.create_all(bind=engine)

app = FastAPI(
    title="Smart Tourist Safety Monitoring System API",
    description="Backend for the Tourist Mobile Application and Admin Dashboard.",
    version="1.0.0",
)

# Allow the Flutter app / admin dashboard to call this API from any origin.
# Tighten this to specific origins in production.
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

app.include_router(auth.router)
app.include_router(location.router)
app.include_router(sos.router)


@app.get("/", tags=["health"])
def health_check():
    return {"status": "ok", "service": "tourist-safety-api"}
