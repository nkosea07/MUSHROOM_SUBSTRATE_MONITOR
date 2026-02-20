import json
import os
from datetime import datetime
from typing import Any

import pandas as pd
import plotly.graph_objects as go
import requests
import streamlit as st

try:
    from streamlit_autorefresh import st_autorefresh
except Exception:  # pragma: no cover
    st_autorefresh = None


DEFAULT_BACKEND_URL = os.getenv("BACKEND_API_URL", "http://localhost:8000/api")
REQUEST_TIMEOUT = 8


st.set_page_config(page_title="Mushroom Monitoring Dashboard", layout="wide")


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
        return response.json() if response.content else {}, None
    except requests.RequestException as exc:
        return None, str(exc)


def api_put(base_url: str, path: str, payload: dict[str, Any]) -> tuple[dict[str, Any] | None, str | None]:
    try:
        response = requests.put(f"{base_url}{path}", json=payload, timeout=REQUEST_TIMEOUT)
        response.raise_for_status()
        return response.json() if response.content else {}, None
    except requests.RequestException as exc:
        return None, str(exc)


def status_label(status: str) -> str:
    labels = {
        "optimal": "Stable",
        "low": "Too Low",
        "high": "Too High",
        "unknown": "Unknown",
    }
    return labels.get(status, status.title())


def status_class(status: str) -> str:
    classes = {
        "optimal": "ok",
        "low": "warn",
        "high": "warn",
        "unknown": "idle",
    }
    return classes.get(status, "idle")


def fmt_time(value: Any) -> str:
    if value is None:
        return "--:--:--"
    try:
        dt = pd.to_datetime(value)
        return dt.strftime("%H:%M:%S")
    except Exception:
        return str(value)


def fmt_value(value: Any, suffix: str = "", digits: int = 1) -> str:
    if value is None:
        return "--"
    if isinstance(value, (int, float)):
        return f"{value:.{digits}f}{suffix}"
    return f"{value}{suffix}"


def refresh_page() -> None:
    if hasattr(st, "rerun"):
        st.rerun()
    st.experimental_rerun()


st.markdown(
    """
<style>
:root {
  --bg: #f3f5f7;
  --card: #f7f9fc;
  --panel: #edf1f5;
  --text: #2c3342;
  --muted: #6d788b;
  --line: #dbe2ea;
  --green: #38a169;
  --green-bg: #e8f7ee;
  --blue: #3867d6;
  --blue-bg: #e8eefc;
  --amber: #d08a1f;
  --amber-bg: #faf4e4;
}

html, body, [class*="css"] {
  font-family: "Segoe UI", "Inter", sans-serif;
}

.stApp {
  background: var(--bg);
}

.block-container {
  padding-top: 1rem;
  padding-bottom: 2rem;
  max-width: 1380px;
}

.section-card {
  background: #f8fafc;
  border: 1px solid var(--line);
  border-radius: 16px;
  padding: 14px 16px;
}

.metric-card {
  border-radius: 14px;
  padding: 18px;
  border: 1px solid transparent;
  min-height: 150px;
}

.metric-title {
  color: #455267;
  font-size: 1.15rem;
  font-weight: 600;
}

.metric-value {
  font-size: 2.7rem;
  font-weight: 700;
  margin: 14px 0 10px;
}

.metric-stable {
  color: #6f7e95;
  font-weight: 600;
}

.temp-card { background: var(--green-bg); border-color: #cae8d7; }
.temp-card .metric-value { color: var(--green); }

.humidity-card { background: var(--blue-bg); border-color: #d2dcfb; }
.humidity-card .metric-value { color: var(--blue); }

.ph-card { background: var(--amber-bg); border-color: #ecd9a6; }
.ph-card .metric-value { color: var(--amber); }

.deviation-row {
  border: 1px solid #cfe8d7;
  background: #edf8f1;
  border-radius: 10px;
  padding: 11px 14px;
  margin: 8px 0;
  display: flex;
  justify-content: space-between;
  align-items: center;
}

.deviation-meta {
  color: #58657b;
  font-weight: 600;
}

.badge {
  padding: 5px 10px;
  border-radius: 8px;
  font-size: 0.9rem;
  font-weight: 700;
}

.badge.ok { background: #d9f5e4; color: #2f855a; }
.badge.warn { background: #fbe9d7; color: #b7791f; }
.badge.idle { background: #e9edf3; color: #5a677d; }

.log-row {
  border: 1px solid #e3e8ef;
  background: #f6f8fb;
  border-radius: 10px;
  padding: 10px 12px;
  margin: 7px 0;
  display: grid;
  grid-template-columns: 1.2fr 1fr 1fr 1fr;
  gap: 10px;
  font-weight: 600;
}

.report-grid {
  display: grid;
  grid-template-columns: repeat(3, minmax(0, 1fr));
  gap: 10px;
}

.report-box {
  border-radius: 10px;
  border: 1px solid var(--line);
  padding: 10px 12px;
  background: #f9fbff;
}

.report-label {
  color: #5e6a7f;
  font-size: 0.92rem;
  font-weight: 600;
}

.report-value {
  color: #283142;
  font-size: 1.5rem;
  font-weight: 700;
}

.control-title {
  font-size: 2rem;
  font-weight: 700;
  margin-bottom: 0;
  color: #313a4b;
}

.control-subtitle {
  color: #6e7b90;
  margin-bottom: 14px;
  font-weight: 600;
}

.small-muted {
  color: #7a869a;
  font-size: 0.88rem;
  font-weight: 600;
}

h1, h2, h3 {
  color: #313a4b;
}
</style>
""",
    unsafe_allow_html=True,
)

backend_url = st.session_state.get("backend_url", DEFAULT_BACKEND_URL)

left, right = st.columns([1.05, 2.95], gap="large")

with left:
    st.markdown("## Control Panel")
    st.markdown("<div class='small-muted'>Mushroom Substrate Monitoring System</div>", unsafe_allow_html=True)

    with st.expander("Connection", expanded=False):
        backend_url = st.text_input("Backend API URL", value=backend_url)
        st.session_state["backend_url"] = backend_url
        auto_refresh = st.checkbox("Auto refresh", value=True)
        refresh_seconds = st.slider("Refresh (seconds)", 5, 60, 15, 5)

if st.session_state.get("backend_url"):
    backend_url = st.session_state["backend_url"]

if "auto_refresh" not in locals():
    auto_refresh = True
    refresh_seconds = 15

if auto_refresh and st_autorefresh:
    st_autorefresh(interval=refresh_seconds * 1000, key="dashboard-refresh")

health, health_error = api_get(backend_url, "/health")
if health_error:
    st.error(f"Backend unavailable: {health_error}")
    st.stop()

settings, settings_error = api_get(backend_url, "/settings/targets")
if settings_error:
    settings = {
        "temp_min": 22.0,
        "temp_max": 26.0,
        "moisture_min": 60,
        "moisture_max": 70,
        "ph_min": 6.5,
        "ph_max": 7.0,
    }

control_state, state_error = api_get(backend_url, "/control/state")
if state_error:
    control_state = {
        "mode": "AUTO",
        "fan": False,
        "heater": False,
        "humidifier": False,
        "ph_actuator": False,
    }

runtime_mode, runtime_error = api_get(backend_url, "/runtime/mode")
if runtime_error:
    runtime_mode = {
        "mode": "live",
        "esp32_base_url": "unknown",
        "allow_live_fallback": False,
    }

report, report_error = api_get(backend_url, "/monitoring/report?points=20&log_items=10")
if report_error:
    st.error(f"Monitoring report unavailable: {report_error}")
    st.stop()

with left:
    current_runtime_mode = str(runtime_mode.get("mode", "live")).lower()
    st.markdown("### Environment")
    with st.form("runtime-mode-form"):
        runtime_choice = st.radio(
            "Data Source",
            ["live", "mock"],
            horizontal=True,
            index=0 if current_runtime_mode == "live" else 1,
            format_func=lambda item: item.upper(),
        )
        switch_runtime = st.form_submit_button("Switch Environment", use_container_width=True)

    if switch_runtime:
        updated_runtime, runtime_update_err = api_put(backend_url, "/runtime/mode", {"mode": runtime_choice})
        if runtime_update_err:
            st.error(f"Failed to switch runtime mode: {runtime_update_err}")
        else:
            runtime_mode = updated_runtime
            st.success(f"Environment switched to {runtime_choice.upper()}")
            refresh_page()

    st.caption(
        f"Current: {str(runtime_mode.get('mode', 'live')).upper()} | "
        f"ESP32: {runtime_mode.get('esp32_base_url', 'unknown')}"
    )

    st.markdown("### Set Optimal Conditions")
    with st.form("targets-form"):
        temp_range = st.slider(
            "Target Temperature",
            min_value=15.0,
            max_value=35.0,
            value=(float(settings["temp_min"]), float(settings["temp_max"])),
            step=0.5,
            format="%.1f°C",
        )
        humidity_range = st.slider(
            "Target Humidity",
            min_value=50,
            max_value=100,
            value=(int(settings["moisture_min"]), int(settings["moisture_max"])),
            step=1,
            format="%d%%",
        )
        ph_range = st.slider(
            "Target pH",
            min_value=4.0,
            max_value=8.0,
            value=(float(settings["ph_min"]), float(settings["ph_max"])),
            step=0.1,
            format="%.1f",
        )

        apply_targets = st.form_submit_button("Apply Optimal Conditions", use_container_width=True)

    if apply_targets:
        target_payload = {
            "temp_min": temp_range[0],
            "temp_max": temp_range[1],
            "moisture_min": humidity_range[0],
            "moisture_max": humidity_range[1],
            "ph_min": ph_range[0],
            "ph_max": ph_range[1],
        }
        updated_targets, target_err = api_put(backend_url, "/settings/targets", target_payload)
        if target_err:
            st.error(f"Failed to update targets: {target_err}")
        else:
            settings = updated_targets
            st.success("Optimal conditions updated")
            refresh_page()

    mode_choice = st.radio(
        "System Mode",
        ["AUTO", "MANUAL"],
        horizontal=True,
        index=0 if str(control_state.get("mode", "AUTO")).upper() == "AUTO" else 1,
    )
    if st.button("Apply Mode", use_container_width=True):
        mode_result, mode_err = api_post(backend_url, "/control", {"mode": mode_choice})
        if mode_err:
            st.error(f"Mode update failed: {mode_err}")
        else:
            st.success(f"Mode set to {mode_choice}")
            mode_warning = ((mode_result or {}).get("payload") or {}).get("warning")
            if mode_warning:
                st.warning(mode_warning)
            refresh_page()

    st.markdown("### Actuators")
    with st.form("actuator-form"):
        heater_toggle = st.toggle("Activate Heater", value=bool(control_state.get("heater", False)))
        humidifier_toggle = st.toggle("Activate Humidifier", value=bool(control_state.get("humidifier", False)))
        ph_toggle = st.toggle("Activate pH Actuator", value=bool(control_state.get("ph_actuator", False)))
        fan_toggle = st.toggle("Activate Fan", value=bool(control_state.get("fan", False)))
        apply_actuators = st.form_submit_button("Apply Manual Actuators", use_container_width=True)

    if apply_actuators:
        command = {
            "mode": "MANUAL",
            "heater": heater_toggle,
            "humidifier": humidifier_toggle,
            "ph_actuator": ph_toggle,
            "fan": fan_toggle,
        }
        control_result, control_err = api_post(backend_url, "/control", command)
        if control_err:
            st.error(f"Control failed: {control_err}")
        else:
            st.success("Actuator states updated")
            control_warning = ((control_result or {}).get("payload") or {}).get("warning")
            if control_warning:
                st.warning(control_warning)
            refresh_page()

    if st.button("Collect Reading (Current Environment)", use_container_width=True):
        _, collect_err = api_post(backend_url, "/sensor/collect")
        if collect_err:
            st.error(collect_err)
        else:
            st.success("Reading collected")
            refresh_page()

with right:
    st.markdown("<div class='control-title'>Monitoring Dashboard</div>", unsafe_allow_html=True)
    st.markdown(
        (
            "<div class='control-subtitle'>Real-time substrate conditions | "
            f"Environment: {str(runtime_mode.get('mode', 'live')).upper()}</div>"
        ),
        unsafe_allow_html=True,
    )

    current = report.get("current") or {}
    deviation = report.get("deviation") or {}
    targets = report.get("targets") or settings

    card_col1, card_col2, card_col3 = st.columns(3)

    with card_col1:
        st.markdown(
            f"""
<div class='metric-card temp-card'>
  <div class='metric-title'>Temperature</div>
  <div class='metric-value'>{fmt_value(current.get('temperature'), '°C', 1)}</div>
  <div class='metric-stable'>● {status_label((deviation.get('temperature') or {}).get('status', 'unknown'))}</div>
</div>
""",
            unsafe_allow_html=True,
        )

    with card_col2:
        st.markdown(
            f"""
<div class='metric-card humidity-card'>
  <div class='metric-title'>Humidity</div>
  <div class='metric-value'>{fmt_value(current.get('moisture'), '%', 0)}</div>
  <div class='metric-stable'>● {status_label((deviation.get('moisture') or {}).get('status', 'unknown'))}</div>
</div>
""",
            unsafe_allow_html=True,
        )

    with card_col3:
        st.markdown(
            f"""
<div class='metric-card ph-card'>
  <div class='metric-title'>pH Level</div>
  <div class='metric-value'>{fmt_value(current.get('ph'), '', 2)}</div>
  <div class='metric-stable'>● {status_label((deviation.get('ph') or {}).get('status', 'unknown'))}</div>
</div>
""",
            unsafe_allow_html=True,
        )

    st.markdown("#### Deviation Detection")
    for key, label, suffix in [
        ("temperature", "Temperature", "°C"),
        ("moisture", "Humidity", "%"),
        ("ph", "pH Level", ""),
    ]:
        item = deviation.get(key) or {}
        status = item.get("status", "unknown")
        st.markdown(
            f"""
<div class='deviation-row'>
  <div>
    <div><strong>{label}</strong></div>
    <div class='deviation-meta'>Current: {fmt_value(item.get('current'), suffix, 1)} | Target: {fmt_value(item.get('target'), suffix, 1)}</div>
  </div>
  <span class='badge {status_class(status)}'>{status_label(status)}</span>
</div>
""",
            unsafe_allow_html=True,
        )

    st.markdown("#### Live Sensor Readings (Last 20 Points)")
    series = report.get("live_series") or []
    if series:
        df_series = pd.DataFrame(series)
        df_series["timestamp"] = pd.to_datetime(df_series["timestamp"])

        fig = go.Figure()
        fig.add_trace(
            go.Scatter(
                x=df_series["timestamp"],
                y=df_series["moisture"],
                mode="lines+markers",
                name="Humidity (%)",
                line={"color": "#3867d6", "width": 2},
                marker={"size": 6},
            )
        )
        fig.add_trace(
            go.Scatter(
                x=df_series["timestamp"],
                y=df_series["temperature"],
                mode="lines+markers",
                name="Temperature (°C)",
                line={"color": "#38a169", "width": 2},
                marker={"size": 6},
            )
        )
        fig.add_trace(
            go.Scatter(
                x=df_series["timestamp"],
                y=df_series["ph"],
                mode="lines+markers",
                name="pH",
                line={"color": "#d08a1f", "width": 2},
                marker={"size": 6},
            )
        )

        fig.update_layout(
            template="plotly_white",
            margin={"l": 10, "r": 10, "t": 10, "b": 10},
            legend={"orientation": "h", "y": -0.2},
            xaxis_title="",
            yaxis_title="",
            height=320,
        )
        st.plotly_chart(fig, use_container_width=True)
    else:
        st.info("No live series data yet. Use Collect Reading after selecting an environment.")

    bottom_left, bottom_right = st.columns([1, 1], gap="large")

    with bottom_left:
        st.markdown("#### Sensor Readings Log")
        log_rows = report.get("readings_log") or []
        if not log_rows:
            st.info("No readings logged yet")
        else:
            for row in log_rows:
                st.markdown(
                    f"""
<div class='log-row'>
  <span>{fmt_time(row.get('timestamp'))}</span>
  <span style='color:#2f855a'>{fmt_value(row.get('temperature'), '°C', 1)}</span>
  <span style='color:#3867d6'>{fmt_value(row.get('moisture'), '%', 0)}</span>
  <span style='color:#d08a1f'>pH {fmt_value(row.get('ph'), '', 2)}</span>
</div>
""",
                    unsafe_allow_html=True,
                )

    with bottom_right:
        st.markdown("#### Monitoring Report")
        report_meta = report.get("report") or {}
        statuses = (report_meta.get("status") or {})
        averages = (report_meta.get("averages") or {})

        st.markdown(
            f"""
<div class='report-grid'>
  <div class='report-box'><div class='report-label'>Temp Status</div><div class='report-value'>{status_label(statuses.get('temperature', 'unknown'))}</div></div>
  <div class='report-box'><div class='report-label'>Humidity Status</div><div class='report-value'>{status_label(statuses.get('moisture', 'unknown'))}</div></div>
  <div class='report-box'><div class='report-label'>pH Status</div><div class='report-value'>{status_label(statuses.get('ph', 'unknown'))}</div></div>
  <div class='report-box'><div class='report-label'>Avg Temp</div><div class='report-value'>{fmt_value(averages.get('temperature'), '°C', 1)}</div><div class='small-muted'>Target: {(targets.get('temp_min') + targets.get('temp_max'))/2:.1f}°C</div></div>
  <div class='report-box'><div class='report-label'>Avg Humidity</div><div class='report-value'>{fmt_value(averages.get('moisture'), '%', 1)}</div><div class='small-muted'>Target: {(targets.get('moisture_min') + targets.get('moisture_max'))/2:.1f}%</div></div>
  <div class='report-box'><div class='report-label'>Avg pH</div><div class='report-value'>{fmt_value(averages.get('ph'), '', 2)}</div><div class='small-muted'>Target: {(targets.get('ph_min') + targets.get('ph_max'))/2:.2f}</div></div>
</div>
""",
            unsafe_allow_html=True,
        )

        st.markdown(
            f"""
<div class='section-card' style='margin-top:10px;'>
  <div><strong>Total Readings:</strong> {report_meta.get('total_readings', 0)}</div>
  <div><strong>Active Actuators:</strong> {report_meta.get('active_actuators', 0)}/{report_meta.get('max_actuators', 4)}</div>
</div>
""",
            unsafe_allow_html=True,
        )

        report_payload = {
            "generated_at": datetime.utcnow().isoformat(),
            "report": report,
        }
        st.download_button(
            "Download Full Report with Charts",
            data=json.dumps(report_payload, indent=2, default=str),
            file_name="mushroom_monitoring_report.json",
            mime="application/json",
            use_container_width=True,
        )
