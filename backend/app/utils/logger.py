import logging
import sys
from app.core.config import settings

def setup_logging() -> logging.Logger:
    """Setup application logging"""
    
    # Create logger
    logger = logging.getLogger("mushroom_monitor")
    logger.setLevel(getattr(logging, settings.LOG_LEVEL.upper()))
    
    # Create handlers
    console_handler = logging.StreamHandler(sys.stdout)
    file_handler = logging.FileHandler("logs/application.log")
    
    # Create formatter
    formatter = logging.Formatter(
        '%(asctime)s - %(name)s - %(levelname)s - %(message)s'
    )
    
    # Add formatter to handlers
    console_handler.setFormatter(formatter)
    file_handler.setFormatter(formatter)
    
    # Add handlers to logger
    logger.addHandler(console_handler)
    logger.addHandler(file_handler)
    
    return logger
