from sqlalchemy import Column, Integer, String, DateTime, Float
from sqlalchemy.sql import func
from app.core.database import Base

class ActuatorLog(Base):
    __tablename__ = "actuator_logs"
    
    id = Column(Integer, primary_key=True, index=True)
    timestamp = Column(DateTime(timezone=True), server_default=func.now(), index=True)
    actuator_type = Column(String, nullable=False)
    action = Column(String, nullable=False)
    duration_seconds = Column(Float, default=0.0)
    triggered_by = Column(String, nullable=False)
    sensor_temperature = Column(Float, nullable=True)
    sensor_moisture = Column(Integer, nullable=True)
    sensor_ph = Column(Float, nullable=True)
    
    def __repr__(self):
        return f"<ActuatorLog(actuator={self.actuator_type}, action={self.action})>"
