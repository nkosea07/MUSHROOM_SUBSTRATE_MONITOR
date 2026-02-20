from datetime import datetime

from pydantic import BaseModel, ConfigDict


class AlertOut(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: int
    timestamp: datetime
    severity: str
    parameter: str
    message: str
    threshold_value: float | None
    current_value: float | None
    resolved: bool
    resolved_at: datetime | None


class AlertListResponse(BaseModel):
    items: list[AlertOut]
    count: int
