import os
from typing import Any

import pandas as pd
import plotly.express as px
import requests
import streamlit as st

try:
    from streamlit_autorefresh import st_autorefresh
except Exception:  # pragma: no cover - optional dependency fallback
    st_autorefresh = None


DEFAULT_BACKEND_URL = os.getenv("BACKEND_API_URL", "http://localhost:8000/api")
REQUEST_TIMEOUT = 8


st.set_page_config(page_title="Mushroom MVP Dashboard", layout="wide")


def api_get(base_url: str, path: str) -> tuple[dict[str, Any] | None, str | None]:
    try:
        response = requests.get(f"{base_url}{path}", timeout=REQUEST_TIMEOUT)
        response.raise_for_status()
        return response.json(), None
    except requests.RequestException as exc:
        return None, str(exc)


def api_post(base_url: str, path: str, payload: dict[str, Any] | None = None) -> tuple[dict[str, Any] | None, str | None]:
    try:
        response = requests.post(f"{base_url}{path}", json=payload or {}, timeout=REQUEST_TIMEOUT)
        response.raise_for_status()
        if response.content:
            return response.json(), None
        return {}, None
    except requests.RequestException as exc:
        return None, str(exc)


def format_status(value: float, min_value: float, max_value: float) -> str:
    if value < min_value:
        return "LOW"
    if value > max_value:
        return "HIGH"
    return "OK"


st.title("Mushroom Substrate Monitor")
st.caption("MVP dashboard for temperature, moisture, pH, control actions, and basic alerts")

with st.sidebar:
    st.header("Settings")
    backend_url = st.text_input("Backend API URL", value=DEFAULT_BACKEND_URL)
    auto_refresh = st.checkbox("Auto refresh", value=True)
    refresh_seconds = st.slider("Refresh interval (seconds)", min_value=5, max_value=60, value=15, step=5)

if auto_refresh and st_autorefresh:
    st_autorefresh(interval=refresh_seconds * 1000, key="mvp-refresh")

health_payload, health_error = api_get(backend_url, "/health")
if health_error:
    st.error(f"Backend unavailable: {health_error}")
    st.stop()

left, right = st.columns([2, 1])
with left:
    st.subheader("Live Readings")
with right:
    if st.button("Sync from ESP32", use_container_width=True):
        _, sync_error = api_post(backend_url, "/sensor/sync")
        if sync_error:
            st.error(f"Sync failed: {sync_error}")
        else:
            st.success("Synced latest reading from ESP32")

latest_payload, latest_error = api_get(backend_url, "/sensor/latest")
if latest_error:
    st.warning("No sensor records yet. Click 'Sync from ESP32' or POST /api/sensor/ingest.")
else:
    temp = float(latest_payload["temperature"])
    moisture = float(latest_payload["moisture"])
    ph_value = float(latest_payload.get("ph") or 7.0)

    temp_status = format_status(temp, latest_payload["temp_min"], latest_payload["temp_max"])
    moisture_status = format_status(moisture, latest_payload["moisture_min"], latest_payload["moisture_max"])
    ph_status = format_status(ph_value, latest_payload["ph_min"], latest_payload["ph_max"])

    m1, m2, m3 = st.columns(3)
    m1.metric("Temperature", f"{temp:.1f} C", temp_status)
    m2.metric("Moisture", f"{moisture:.0f}%", moisture_status)
    m3.metric("pH", f"{ph_value:.2f}", ph_status)

st.subheader("Manual Controls")
control_col1, control_col2 = st.columns([1, 2])

with control_col1:
    selected_mode = st.radio("System Mode", ["AUTO", "MANUAL"], horizontal=True)
    if st.button("Apply Mode", use_container_width=True):
        _, control_error = api_post(backend_url, "/control", {"mode": selected_mode})
        if control_error:
            st.error(f"Mode update failed: {control_error}")
        else:
            st.success(f"Mode set to {selected_mode}")

with control_col2:
    fan_col, heater_col, humid_col = st.columns(3)
    with fan_col:
        st.write("Fan")
        if st.button("Fan ON", use_container_width=True):
            _, err = api_post(backend_url, "/control", {"fan": True})
            st.error(err) if err else st.success("Fan ON command sent")
        if st.button("Fan OFF", use_container_width=True):
            _, err = api_post(backend_url, "/control", {"fan": False})
            st.error(err) if err else st.success("Fan OFF command sent")
    with heater_col:
        st.write("Heater")
        if st.button("Heater ON", use_container_width=True):
            _, err = api_post(backend_url, "/control", {"heater": True})
            st.error(err) if err else st.success("Heater ON command sent")
        if st.button("Heater OFF", use_container_width=True):
            _, err = api_post(backend_url, "/control", {"heater": False})
            st.error(err) if err else st.success("Heater OFF command sent")
    with humid_col:
        st.write("Humidifier")
        if st.button("Humidifier ON", use_container_width=True):
            _, err = api_post(backend_url, "/control", {"humidifier": True})
            st.error(err) if err else st.success("Humidifier ON command sent")
        if st.button("Humidifier OFF", use_container_width=True):
            _, err = api_post(backend_url, "/control", {"humidifier": False})
            st.error(err) if err else st.success("Humidifier OFF command sent")

st.subheader("Sensor Trends")
history_payload, history_error = api_get(backend_url, "/sensor/history?limit=240")
if history_error:
    st.warning(f"History unavailable: {history_error}")
else:
    rows = history_payload.get("items", [])
    if not rows:
        st.info("No historical data yet")
    else:
        df = pd.DataFrame(rows)
        df["timestamp"] = pd.to_datetime(df["timestamp"])
        df = df.sort_values("timestamp")

        fig_temp = px.line(df, x="timestamp", y="temperature", title="Temperature (C)")
        fig_moisture = px.line(df, x="timestamp", y="moisture", title="Moisture (%)")
        fig_ph = px.line(df, x="timestamp", y="ph", title="pH")

        c1, c2, c3 = st.columns(3)
        c1.plotly_chart(fig_temp, use_container_width=True)
        c2.plotly_chart(fig_moisture, use_container_width=True)
        c3.plotly_chart(fig_ph, use_container_width=True)

st.subheader("Unresolved Alerts")
alerts_payload, alerts_error = api_get(backend_url, "/alerts?unresolved_only=true")
if alerts_error:
    st.warning(f"Alerts unavailable: {alerts_error}")
else:
    alerts = alerts_payload.get("items", [])
    if not alerts:
        st.success("No unresolved alerts")
    else:
        for alert in alerts:
            st.error(
                f"[{alert['severity'].upper()}] {alert['parameter']} - {alert['message']}"
            )
