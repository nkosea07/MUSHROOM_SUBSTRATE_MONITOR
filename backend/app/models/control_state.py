from sqlalchemy import Column, Integer, String, DateTime, Boolean
from sqlalchemy.sql import func

from app.core.database import Base


class ControlState(Base):
    __tablename__ = "control_state"

    id = Column(Integer, primary_key=True, index=True)
    updated_at = Column(DateTime(timezone=True), server_default=func.now(), onupdate=func.now())

    mode = Column(String, default="AUTO", nullable=False)
    fan = Column(Boolean, default=False, nullable=False)
    heater = Column(Boolean, default=False, nullable=False)
    humidifier = Column(Boolean, default=False, nullable=False)
    ph_actuator = Column(Boolean, default=False, nullable=False)

    def __repr__(self) -> str:
        return (
            f"<ControlState(mode={self.mode}, fan={self.fan}, heater={self.heater}, "
            f"humidifier={self.humidifier}, ph_actuator={self.ph_actuator})>"
        )
