import os
from dataclasses import dataclass


@dataclass(frozen=True)
class Settings:
    environment: str = os.getenv("ENVIRONMENT", "development")
    debug: bool = os.getenv("DEBUG", "true").lower() == "true"
    host: str = os.getenv("HOST", "0.0.0.0")
    port: int = int(os.getenv("PORT", "8000"))
    cors_origins_raw: str = os.getenv("CORS_ORIGINS", "http://localhost:8501")
    database_url: str = os.getenv("DATABASE_URL", "sqlite:///./mushroom.db")
    esp32_base_url: str = os.getenv("ESP32_BASE_URL", "http://192.168.1.100")
    esp32_timeout: int = int(os.getenv("ESP32_TIMEOUT", "10"))
    runtime_mode_default: str = os.getenv("RUNTIME_MODE_DEFAULT", "live")
    allow_live_fallback: bool = os.getenv("ALLOW_LIVE_FALLBACK", "false").lower() == "true"
    log_level: str = os.getenv("LOG_LEVEL", "INFO")

    @property
    def cors_origins(self) -> list[str]:
        return [item.strip() for item in self.cors_origins_raw.split(",") if item.strip()]


settings = Settings()
