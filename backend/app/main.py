import logging

from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware

from app.api import router
from app.core import Base, engine, settings
from app.models import ActuatorLog, Alert, ControlState, RuntimeMode, SensorData, SystemSettings  # noqa: F401

logging.basicConfig(level=getattr(logging, settings.log_level.upper(), logging.INFO))

app = FastAPI(
    title="Mushroom Substrate Monitor API",
    version="0.1.0",
    description="MVP backend for monitoring sensor data and controlling actuators.",
)

app.add_middleware(
    CORSMiddleware,
    allow_origins=settings.cors_origins,
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

app.include_router(router, prefix="/api")


@app.on_event("startup")
def on_startup() -> None:
    Base.metadata.create_all(bind=engine)


@app.get("/")
def root() -> dict[str, str]:
    return {"message": "Mushroom backend is running", "docs": "/docs"}
