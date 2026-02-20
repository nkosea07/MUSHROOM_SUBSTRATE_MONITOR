from typing import List, Optional, Dict, Any
from sqlalchemy.orm import Session
from sqlalchemy import select, desc
from datetime import datetime, timedelta

from app.models.alert import Alert

class CRUDAlert:
    def create(self, db: Session, obj_in: Dict[str, Any]) -> Alert:
        db_obj = Alert(**obj_in)
        db.add(db_obj)
        db.commit()
        db.refresh(db_obj)
        return db_obj
    
    def get_unresolved_alerts(
        self,
        db: Session,
        severity: Optional[str] = None
    ) -> List[Alert]:
        query = select(Alert).where(Alert.resolved == False)
        
        if severity:
            query = query.where(Alert.severity == severity)
        
        query = query.order_by(desc(Alert.timestamp))
        result = db.execute(query)
        return result.scalars().all()
    
    def resolve_alert(self, db: Session, alert_id: int) -> Optional[Alert]:
        result = db.execute(
            select(Alert).where(Alert.id == alert_id)
        )
        alert = result.scalar_one_or_none()
        
        if alert:
            alert.resolved = True
            alert.resolved_at = datetime.utcnow()
            db.commit()
            db.refresh(alert)
        
        return alert
    
    def get_recent_alerts(
        self,
        db: Session,
        hours: int = 24,
        limit: int = 100
    ) -> List[Alert]:
        start_time = datetime.utcnow() - timedelta(hours=hours)
        query = select(Alert).where(
            Alert.timestamp >= start_time
        ).order_by(desc(Alert.timestamp)).limit(limit)
        
        result = db.execute(query)
        return result.scalars().all()

alert_crud = CRUDAlert()
