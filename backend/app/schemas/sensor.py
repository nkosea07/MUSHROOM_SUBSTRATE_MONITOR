from datetime import datetime

from pydantic import BaseModel, ConfigDict, Field


class Thresholds(BaseModel):
    temp_min: float = 22.0
    temp_max: float = 26.0
    moisture_min: int = 60
    moisture_max: int = 70
    ph_min: float = 6.5
    ph_max: float = 7.0


class SensorIn(BaseModel):
    temperature: float = Field(..., description="Temperature in Celsius")
    moisture: int = Field(..., ge=0, le=100, description="Moisture percentage")
    ph: float | None = Field(default=7.0, ge=0.0, le=14.0)
    timestamp: datetime | None = None
    thresholds: Thresholds | None = None
    device_id: str | None = None
    location: str | None = None


class SensorOut(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: int
    timestamp: datetime
    temperature: float
    moisture: int
    ph: float | None
    temp_min: float
    temp_max: float
    moisture_min: int
    moisture_max: int
    ph_min: float
    ph_max: float
    device_id: str | None
    location: str | None


class SensorHistoryResponse(BaseModel):
    items: list[SensorOut]
    count: int
