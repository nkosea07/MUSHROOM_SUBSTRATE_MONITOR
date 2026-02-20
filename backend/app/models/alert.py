from sqlalchemy import Column, Integer, String, DateTime, Boolean, Float
from sqlalchemy.sql import func
from app.core.database import Base

class Alert(Base):
    __tablename__ = "alerts"
    
    id = Column(Integer, primary_key=True, index=True)
    timestamp = Column(DateTime(timezone=True), server_default=func.now(), index=True)
    severity = Column(String, nullable=False)  # info, warning, critical
    parameter = Column(String, nullable=False)  # temperature, moisture, ph
    message = Column(String, nullable=False)
    threshold_value = Column(Float, nullable=True)
    current_value = Column(Float, nullable=True)
    resolved = Column(Boolean, default=False)
    resolved_at = Column(DateTime(timezone=True), nullable=True)
    
    def __repr__(self):
        return f"<Alert(severity={self.severity}, parameter={self.parameter})>"
