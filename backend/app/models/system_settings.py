from sqlalchemy import Column, Integer, Float, DateTime
from sqlalchemy.sql import func

from app.core.database import Base


class SystemSettings(Base):
    __tablename__ = "system_settings"

    id = Column(Integer, primary_key=True, index=True)
    updated_at = Column(DateTime(timezone=True), server_default=func.now(), onupdate=func.now())

    temp_min = Column(Float, default=22.0, nullable=False)
    temp_max = Column(Float, default=26.0, nullable=False)
    moisture_min = Column(Integer, default=60, nullable=False)
    moisture_max = Column(Integer, default=70, nullable=False)
    ph_min = Column(Float, default=6.5, nullable=False)
    ph_max = Column(Float, default=7.0, nullable=False)

    def __repr__(self) -> str:
        return (
            f"<SystemSettings(temp={self.temp_min}-{self.temp_max}, "
            f"moisture={self.moisture_min}-{self.moisture_max}, "
            f"ph={self.ph_min}-{self.ph_max})>"
        )
