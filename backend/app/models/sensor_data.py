from sqlalchemy import Column, Integer, Float, DateTime, String
from sqlalchemy.sql import func
from app.core.database import Base

class SensorData(Base):
    __tablename__ = "sensor_data"
    
    id = Column(Integer, primary_key=True, index=True)
    timestamp = Column(DateTime(timezone=True), server_default=func.now(), index=True)
    temperature = Column(Float, nullable=False)
    moisture = Column(Integer, nullable=False)
    ph = Column(Float, nullable=True)
    temp_min = Column(Float, default=22.0)
    temp_max = Column(Float, default=26.0)
    moisture_min = Column(Integer, default=60)
    moisture_max = Column(Integer, default=70)
    ph_min = Column(Float, default=6.5)
    ph_max = Column(Float, default=7.0)
    device_id = Column(String, nullable=True)
    location = Column(String, nullable=True)
    
    def __repr__(self):
        return f"<SensorData(id={self.id}, temp={self.temperature}, moisture={self.moisture})>"
