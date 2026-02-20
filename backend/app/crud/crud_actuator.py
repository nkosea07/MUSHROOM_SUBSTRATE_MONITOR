from typing import List, Optional, Dict, Any
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select, desc
from datetime import datetime, timedelta

from app.models.actuator_log import ActuatorLog

class CRUDActuator:
    async def create(self, db: AsyncSession, obj_in: Dict[str, Any]) -> ActuatorLog:
        db_obj = ActuatorLog(**obj_in)
        db.add(db_obj)
        await db.commit()
        await db.refresh(db_obj)
        return db_obj
    
    async def get_actuator_history(
        self,
        db: AsyncSession,
        actuator_type: Optional[str] = None,
        limit: int = 50
    ) -> List[ActuatorLog]:
        query = select(ActuatorLog).order_by(desc(ActuatorLog.timestamp))
        
        if actuator_type:
            query = query.where(ActuatorLog.actuator_type == actuator_type)
        
        query = query.limit(limit)
        result = await db.execute(query)
        return result.scalars().all()
    
    async def get_recent_activity(
        self,
        db: AsyncSession,
        hours: int = 24
    ) -> List[ActuatorLog]:
        start_time = datetime.utcnow() - timedelta(hours=hours)
        query = select(ActuatorLog).where(
            ActuatorLog.timestamp >= start_time
        ).order_by(desc(ActuatorLog.timestamp))
        
        result = await db.execute(query)
        return result.scalars().all()

actuator_crud = CRUDActuator()
