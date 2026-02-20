from sqlalchemy import Column, DateTime, Integer, String
from sqlalchemy.sql import func

from app.core.database import Base


class RuntimeMode(Base):
    __tablename__ = "runtime_mode"

    id = Column(Integer, primary_key=True, index=True)
    mode = Column(String, default="live", nullable=False)
    updated_at = Column(DateTime(timezone=True), server_default=func.now(), onupdate=func.now())

    def __repr__(self) -> str:
        return f"<RuntimeMode(mode={self.mode})>"
