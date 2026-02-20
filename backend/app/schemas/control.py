from typing import Literal

from pydantic import BaseModel


class ControlCommand(BaseModel):
    mode: Literal["AUTO", "MANUAL"] | None = None
    fan: bool | str | None = None
    heater: bool | str | None = None
    humidifier: bool | str | None = None
    ph_actuator: bool | str | None = None
    simulate: bool = False


class ControlResponse(BaseModel):
    success: bool
    message: str
    payload: dict
