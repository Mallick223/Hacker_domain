from datetime import datetime
from typing import Optional
from pydantic import BaseModel, EmailStr, ConfigDict
from .models import SosStatus


# ---------- Auth ----------

class UserRegister(BaseModel):
    name: str
    email: EmailStr
    phone: str
    password: str
    emergency_contact: Optional[str] = None


class UserLogin(BaseModel):
    email: EmailStr
    password: str


class UserOut(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: int
    name: str
    email: EmailStr
    phone: str
    emergency_contact: Optional[str] = None


class AuthResponse(BaseModel):
    token: str
    user: UserOut


# ---------- Location ----------

class LocationUpdate(BaseModel):
    lat: float
    lng: float
    speed: Optional[float] = None
    heading: Optional[float] = None
    timestamp: Optional[datetime] = None


class LocationOut(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: int
    user_id: int
    lat: float
    lng: float
    speed: Optional[float]
    heading: Optional[float]
    timestamp: datetime


# ---------- SOS ----------

class SosCreate(BaseModel):
    lat: float
    lng: float
    message: Optional[str] = None
    timestamp: Optional[datetime] = None


class SosOut(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: int
    user_id: int
    lat: float
    lng: float
    message: Optional[str]
    status: SosStatus
    timestamp: datetime


class SosStatusUpdate(BaseModel):
    status: SosStatus
