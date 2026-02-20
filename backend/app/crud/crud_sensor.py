from typing import List, Optional, Dict, Any
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select, desc, func, and_
from datetime import datetime, timedelta
import logging

from app.models.sensor_data import SensorData

logger = logging.getLogger(__name__)

class CRUDSensor:
    async def create(self, db: AsyncSession, obj_in: Dict[str, Any]) -> SensorData:
        db_obj = SensorData(**obj_in)
        db.add(db_obj)
        await db.commit()
        await db.refresh(db_obj)
        return db_obj
    
    async def get(self, db: AsyncSession, id: int) -> Optional[SensorData]:
        result = await db.execute(
            select(SensorData).where(SensorData.id == id)
        )
        return result.scalar_one_or_none()
    
    async def get_multi(
        self, 
        db: AsyncSession, 
        skip: int = 0, 
        limit: int = 100,
        start_time: Optional[datetime] = None,
        end_time: Optional[datetime] = None
    ) -> List[SensorData]:
        query = select(SensorData).order_by(desc(SensorData.timestamp))
        
        if start_time:
            query = query.where(SensorData.timestamp >= start_time)
        if end_time:
            query = query.where(SensorData.timestamp <= end_time)
        
        query = query.offset(skip).limit(limit)
        result = await db.execute(query)
        return result.scalars().all()
    
    async def get_statistics(
        self,
        db: AsyncSession,
        start_time: datetime,
        end_time: datetime
    ) -> Dict[str, Any]:
        result = await db.execute(
            select(
                func.count(SensorData.id).label("count"),
                func.avg(SensorData.temperature).label("avg_temperature"),
                func.min(SensorData.temperature).label("min_temperature"),
                func.max(SensorData.temperature).label("max_temperature"),
                func.avg(SensorData.moisture).label("avg_moisture"),
                func.min(SensorData.moisture).label("min_moisture"),
                func.max(SensorData.moisture).label("max_moisture"),
                func.avg(SensorData.ph).label("avg_ph"),
                func.min(SensorData.ph).label("min_ph"),
                func.max(SensorData.ph).label("max_ph")
            ).where(
                and_(
                    SensorData.timestamp >= start_time,
                    SensorData.timestamp <= end_time
                )
            )
        )
        
        stats = result.first()
        
        return {
            "count": stats.count if stats.count else 0,
            "temperature": {
                "average": round(float(stats.avg_temperature or 0), 2),
                "min": round(float(stats.min_temperature or 0), 2),
                "max": round(float(stats.max_temperature or 0), 2)
            },
            "moisture": {
                "average": int(stats.avg_moisture or 0),
                "min": int(stats.min_moisture or 0),
                "max": int(stats.max_moisture or 0)
            },
            "ph": {
                "average": round(float(stats.avg_ph or 0), 2),
                "min": round(float(stats.min_ph or 0), 2),
                "max": round(float(stats.max_ph or 0), 2)
            }
        }
    
    async def get_recent(self, db: AsyncSession, hours: int = 24) -> List[SensorData]:
        start_time = datetime.utcnow() - timedelta(hours=hours)
        return await self.get_multi(
            db,
            start_time=start_time,
            end_time=datetime.utcnow(),
            limit=1000
        )
    
    async def create_calibration_log(
        self,
        db: AsyncSession,
        sensor_type: str,
        calibration_value: float,
        success: bool = True
    ) -> None:
        logger.info(f"Calibration logged: {sensor_type}={calibration_value}, success={success}")

sensor_crud = CRUDSensor()
