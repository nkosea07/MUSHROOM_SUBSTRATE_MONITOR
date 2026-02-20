from typing import List, Optional, Dict, Any
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select, desc, and_
from datetime import datetime, timedelta

from app.models.alert import Alert

class CRUDAlert:
    async def create(self, db: AsyncSession, obj_in: Dict[str, Any]) -> Alert:
        db_obj = Alert(**obj_in)
        db.add(db_obj)
        await db.commit()
        await db.refresh(db_obj)
        return db_obj
    
    async def get_unresolved_alerts(
        self,
        db: AsyncSession,
        severity: Optional[str] = None
    ) -> List[Alert]:
        query = select(Alert).where(Alert.resolved == False)
        
        if severity:
            query = query.where(Alert.severity == severity)
        
        query = query.order_by(desc(Alert.timestamp))
        result = await db.execute(query)
        return result.scalars().all()
    
    async def resolve_alert(self, db: AsyncSession, alert_id: int) -> Optional[Alert]:
        result = await db.execute(
            select(Alert).where(Alert.id == alert_id)
        )
        alert = result.scalar_one_or_none()
        
        if alert:
            alert.resolved = True
            alert.resolved_at = datetime.utcnow()
            await db.commit()
            await db.refresh(alert)
        
        return alert
    
    async def get_recent_alerts(
        self,
        db: AsyncSession,
        hours: int = 24,
        limit: int = 100
    ) -> List[Alert]:
        start_time = datetime.utcnow() - timedelta(hours=hours)
        query = select(Alert).where(
            Alert.timestamp >= start_time
        ).order_by(desc(Alert.timestamp)).limit(limit)
        
        result = await db.execute(query)
        return result.scalars().all()

alert_crud = CRUDAlert()
