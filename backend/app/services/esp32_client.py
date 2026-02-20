from typing import Any

import requests

from app.core.config import settings


class ESP32Client:
    def __init__(self, base_url: str, timeout: int) -> None:
        self.base_url = base_url.rstrip("/")
        self.timeout = timeout

    def fetch_current_data(self) -> dict[str, Any]:
        response = requests.get(f"{self.base_url}/api/data", timeout=self.timeout)
        response.raise_for_status()
        return response.json()

    def send_control(self, payload: dict[str, Any]) -> dict[str, Any]:
        response = requests.post(f"{self.base_url}/api/control", json=payload, timeout=self.timeout)
        response.raise_for_status()
        return response.json()


esp32_client = ESP32Client(settings.esp32_base_url, settings.esp32_timeout)
