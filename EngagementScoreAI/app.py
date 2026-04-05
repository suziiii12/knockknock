"""
app.py
-------
Streamlit real-time dashboard — macOS compatible.

macOS notes:
  - Uses st.rerun() instead of streamlit-autorefresh (no extra dependency)
  - Camera permission prompt happens automatically on first run
  - Accessibility permission needed for keyboard KPM tracking
  - Tested on macOS 13+ (Ventura/Sonoma) with built-in FaceTime camera

Run:
    streamlit run app.py
"""

import time
import platform
import numpy as np
import streamlit as st
import cv2

# ── Helper functions ──────────────────────────────────────────────────────────
def _draw_hud(frame: np.ndarray, snap):
    """Overlay focus score and state on the camera frame."""
    score = int(snap.focus_score)
    if score >= 70:
        color = (30, 158, 117)
    elif score >= 40:
        color = (30, 165, 186)
    else:
        color = (60, 60, 220)

    h = frame.shape[0]
    cv2.putText(frame, f"Focus: {score}/100",
                (10, 32), cv2.FONT_HERSHEY_SIMPLEX, 0.75, color, 2, cv2.LINE_AA)

    state_label = snap.inferred_state.value.replace("_", " ").title()
    cv2.putText(frame, state_label,
                (10, 58), cv2.FONT_HERSHEY_SIMPLEX, 0.45, color, 1, cv2.LINE_AA)

    daisee_label = f"DAiSEE: {snap.daisee_class.replace('_',' ')}"
    cv2.putText(frame, daisee_label,
                (10, h - 10), cv2.FONT_HERSHEY_SIMPLEX, 0.38, (190, 190, 190), 1, cv2.LINE_AA)


def _render_summary(engine):
    summary = engine.session_summary()
    if not summary:
        st.info("No session data yet.")
        return

    # Get full score history and compute overall session score
    scores = [s.focus_score for s in engine.study_context._history]
    if scores:
        session_score_result = compute_session_score(scores, engine.epoch_sec)
        overall_score = session_score_result.get('session_score', 0)
    else:
        overall_score = 0

    st.markdown("## 📊 Session breakdown")
    c1, c2, c3, c4 = st.columns(4)
    c1.metric("Duration",      f"{summary.get('duration_min', 0):.1f} min")
    c2.metric("Avg focus",     f"{summary.get('avg_focus', 0):.0f} / 100")
    c3.metric("Time focused",  f"{summary.get('time_focused', 0):.0f}%")
    c4.metric("In flow state", f"{summary.get('time_in_flow', 0):.0f}%")

    c5, c6, c7, c8 = st.columns(4)
    c5.metric("Peak score",    f"{summary.get('peak_score', 0):.0f}")
    c6.metric("Trough score",  f"{summary.get('trough_score', 0):.0f}")
    c7.metric("Distracted",    f"{summary.get('time_distracted', 0):.0f}%")
    c8.metric("Overall Score", f"{overall_score:.1f}")

def compute_session_score(scores: list, epoch_sec: float = 5.0) -> dict:
    """
    Full session score with transparent breakdown.
    Final score = blend of percentile anchor + state-time + streak adjustments.
    """
    s = np.array(scores, dtype=float)
    n = len(s)
    if n == 0:
        return {}
    total_sec = n * epoch_sec

    # Component 1: percentile anchor (40% of final score)
    p25  = float(np.percentile(s, 25))
    p50  = float(np.percentile(s, 50))
    p75  = float(np.percentile(s, 75))
    percentile_score = p25 * 0.40 + p50 * 0.40 + p75 * 0.20

    # Component 2: state-time score (40%)
    flow_frac      = float(np.mean(s >= 80))
    focused_frac   = float(np.mean((s >= 60) & (s < 80)))
    surface_frac   = float(np.mean((s >= 40) & (s < 60)))
    distract_frac  = float(np.mean(s < 40))
    state_score = (
        flow_frac    * 100 +
        focused_frac * 75  +
        surface_frac * 35  +
        distract_frac * 0
    )

    # Component 3: streak / drop adjustments (20%)
    # Longest high-focus streak
    max_streak = cur = 0
    for v in s:
        cur = cur + 1 if v >= 65 else 0
        max_streak = max(max_streak, cur)
    streak_min = (max_streak * epoch_sec) / 60

    # Drop count
    drops = int(np.sum(np.diff((s < 35).astype(int)) == 1))

    # Trajectory (linear slope, normalised)
    from scipy import stats
    slope, *_ = stats.linregress(np.arange(n), s)
    trajectory = float(np.clip(slope * n / 50, -1, 1))  # -1 to +1

    adjustment_score = (
        50                              # neutral baseline
        + min(streak_min * 3, 15)       # up to +15 for sustained focus
        - min(drops * 4, 20)            # up to -20 for frequent drops
        + trajectory * 10               # ±10 for trajectory direction
    )
    adjustment_score = float(np.clip(adjustment_score, 0, 100))

    # Final blend
    final = (
        percentile_score * 0.40 +
        state_score      * 0.40 +
        adjustment_score * 0.20
    )
    final = float(np.clip(final, 0, 100))

    return {
        # Final score
        "session_score":       round(final, 1),

        # Sub-components (for transparency)
        "percentile_score":    round(percentile_score, 1),
        "state_time_score":    round(state_score, 1),
        "adjustment_score":    round(adjustment_score, 1),

        # Raw stats (for the breakdown card)
        "avg":                 round(float(np.mean(s)), 1),
        "median":              round(p50, 1),
        "floor":               round(p25, 1),
        "ceiling":             round(p75, 1),
        "flow_pct":            round(flow_frac * 100, 1),
        "focused_pct":         round(focused_frac * 100, 1),
        "distracted_pct":      round(distract_frac * 100, 1),
        "longest_streak_min":  round(streak_min, 1),
        "drop_count":          drops,
        "trajectory":          round(trajectory, 2),
    }

st.set_page_config(
    page_title="Focus Score Pipeline",
    page_icon="🎯",
    layout="wide",
    initial_sidebar_state="expanded",
)

st.markdown("""
<style>
  .score-big { font-size: 3.8rem; font-weight: 600; text-align: center; line-height: 1.1; }
  .state-pill {
    display: inline-block; padding: 5px 16px; border-radius: 20px;
    font-size: 0.85rem; font-weight: 500;
  }
  div[data-testid="metric-container"] {
    background: #f5f5f3; border-radius: 10px; padding: 0.5rem 0.8rem;
  }
  .permission-box {
    background: #fff8e6; border: 1px solid #f0c040;
    border-radius: 8px; padding: 1rem; margin-bottom: 1rem;
    font-size: 0.85rem;
  }
</style>
""", unsafe_allow_html=True)

# ── Colours & labels ──────────────────────────────────────────────────────────
STATE_META = {
    "flow_state":            {"color": "#3B6D11", "emoji": "🌊", "label": "Flow State"},
    "focused":               {"color": "#1D9E75", "emoji": "✅", "label": "Focused"},
    "surface_browsing":      {"color": "#BA7517", "emoji": "🌐", "label": "Surface Browsing"},
    "invisible_distraction": {"color": "#854F0B", "emoji": "😶", "label": "Invisible Distraction"},
    "cognitive_overload":    {"color": "#993C1D", "emoji": "🔥", "label": "Cognitive Overload"},
    "fatigue":               {"color": "#534AB7", "emoji": "😴", "label": "Fatigue"},
    "disengaged":            {"color": "#A32D2D", "emoji": "🔕", "label": "Disengaged"},
    "warming_up":            {"color": "#888780", "emoji": "⏳", "label": "Warming Up"},
}

DAISEE_META = {
    "very_low": {"color": "#E24B4A", "label": "Very Low"},
    "low":      {"color": "#BA7517", "label": "Low"},
    "high":     {"color": "#1D9E75", "label": "High"},
    "very_high":{"color": "#3B6D11", "label": "Very High"},
}


# ── Engine singleton ──────────────────────────────────────────────────────────
@st.cache_resource
def get_engine(camera_index: int, fps: int, epoch_sec: float, content_type: str):
    from knockknock.EngagementScoreAI.pipeline.inference_engine import InferenceEngine
    return InferenceEngine(
        camera_index=camera_index,
        fps=fps,
        epoch_sec=epoch_sec,
        content_type=content_type,
    )


# ── Session state init ────────────────────────────────────────────────────────
for key, default in {
    "engine_running": False,
    "history": [],
    "last_snap": None,
    "show_summary": False,
    "start_time": None,
}.items():
    if key not in st.session_state:
        st.session_state[key] = default


# ── Sidebar ───────────────────────────────────────────────────────────────────
with st.sidebar:
    st.title("⚙️ Settings")

    # macOS permission reminder
    st.markdown("""
    <div class="permission-box">
    <b>macOS permissions needed:</b><br>
    📷 <b>Camera</b> — auto-prompted on first start<br>
    ⌨️ <b>Accessibility</b> (for KPM tracking):<br>
    System Settings → Privacy → Accessibility → add Terminal
    </div>
    """, unsafe_allow_html=True)

    st.subheader("Session")
    content_type = st.selectbox(
        "Content type",
        ["general", "coding", "reading", "video", "math"],
    )

    st.subheader("Pipeline")
    fps        = st.slider("Vision FPS", 5, 15, 10,
                           help="Lower = less CPU. 10fps is recommended for MacBook.")
    epoch_sec  = st.slider("Score epoch (s)", 2.0, 10.0, 5.0, step=1.0)
    cam_idx    = st.number_input("Camera index (0 = built-in)", 0, 4, 0)

    st.subheader("External scores")
    st.caption("Placeholders for TRIBE v2 / Pupil tracker")
    content_demand = st.slider("Content demand", 0, 100, 50)
    cognitive_load = st.slider("Cognitive load",  0, 100, 50)

    st.divider()
    col1, col2 = st.columns(2)
    start_btn  = col1.button("▶ Start", type="primary", use_container_width=True)
    stop_btn   = col2.button("⏹ Stop",  use_container_width=True)
    st.divider()
    summary_btn = st.button("📊 Session summary", use_container_width=True)

    st.caption(f"Python {platform.python_version()} · {platform.machine()}")


# ── Engine lifecycle ──────────────────────────────────────────────────────────
engine = get_engine(int(cam_idx), fps, epoch_sec, content_type)
engine.set_content_demand(content_demand)
engine.set_cognitive_load(cognitive_load)

if start_btn and not st.session_state.engine_running:
    engine.start()
    st.session_state.engine_running = True
    st.session_state.history = []
    st.session_state.last_snap = None
    st.session_state.show_summary = False
    st.session_state.start_time = time.time()

if stop_btn and st.session_state.engine_running:
    engine.stop()
    st.session_state.engine_running = False

if summary_btn:
    st.session_state.show_summary = True


# ── Title ─────────────────────────────────────────────────────────────────────
st.title("🎯 Focus Score Pipeline")
st.caption("DAiSEE-LSTM · MediaPipe FaceMesh + Holistic · Real-time engagement")


# ── Not running ───────────────────────────────────────────────────────────────
if not st.session_state.engine_running:
    if st.session_state.show_summary and st.session_state.history:
        _render_summary(engine)
    else:
        st.info("Press **▶ Start** in the sidebar to begin.")

        st.markdown("### How it works")
        cols = st.columns(4)
        steps = [
            ("📷", "Webcam", "MediaPipe extracts face landmarks + body pose at 10fps"),
            ("🧮", "Features", "11-dim vector: head pose, EAR, gaze, KPM, mouse, posture"),
            ("🧠", "LSTM", "30-frame window → DAiSEE engagement class (0–3)"),
            ("📊", "Score", "Weighted fusion → 0–100 focus score + InferredState"),
        ]
        for col, (icon, title, desc) in zip(cols, steps):
            col.markdown(f"**{icon} {title}**")
            col.caption(desc)
    st.stop()


# ── Tick ──────────────────────────────────────────────────────────────────────
snap = engine.tick()
if snap:
    st.session_state.last_snap = snap
    st.session_state.history.append({
        "ts":    snap.timestamp,
        "score": snap.focus_score,
        "state": snap.inferred_state.value,
        "daisee": snap.daisee_class,
        "conf":  snap.confidence,
    })

last = st.session_state.last_snap


# ── Main layout ───────────────────────────────────────────────────────────────
left, right = st.columns([1, 2], gap="large")

# ── LEFT: Score + state ───────────────────────────────────────────────────────
with left:
    buf_fill = engine.buffer_fill()

    if buf_fill < 1.0:
        st.progress(buf_fill, text=f"Filling window… {int(buf_fill * 100)}%")
        st.caption("Collecting the first 3 seconds of data…")
    elif last:
        sv = last.inferred_state.value
        meta = STATE_META.get(sv, STATE_META["warming_up"])

        score_color = (
            "#3B6D11" if last.focus_score >= 70 else
            "#BA7517" if last.focus_score >= 40 else
            "#A32D2D"
        )
        st.markdown(
            f'<div class="score-big" style="color:{score_color}">'
            f'{int(last.focus_score)}'
            f'<span style="font-size:1.4rem;color:#aaa"> / 100</span>'
            f'</div>',
            unsafe_allow_html=True,
        )
        st.markdown(
            f'<div style="text-align:center;margin:6px 0 14px">'
            f'<span class="state-pill" style="background:{meta["color"]}18;'
            f'color:{meta["color"]};border:1px solid {meta["color"]}50">'
            f'{meta["emoji"]} {meta["label"]}'
            f'</span></div>',
            unsafe_allow_html=True,
        )

        dm = DAISEE_META.get(last.daisee_class, {"color":"#888","label":"—"})
        st.markdown(
            f'<div style="text-align:center;font-size:0.78rem;color:{dm["color"]};'
            f'font-weight:500;margin-bottom:12px">'
            f'DAiSEE: {dm["label"]} &nbsp;·&nbsp; conf {int(last.confidence*100)}%'
            f'</div>',
            unsafe_allow_html=True,
        )

        st.divider()
        m1, m2 = st.columns(2)
        m1.metric("Body engage",   f"{int(last.body_engagement)}")
        m2.metric("Rolling avg",   f"{engine.study_context.rolling_average()}")
        m3, m4 = st.columns(2)
        elapsed = round((time.time() - st.session_state.start_time) / 60, 1) if st.session_state.start_time else 0
        m3.metric("Session",  f"{elapsed} min")
        m4.metric("Epochs",   engine.epoch_count())
    else:
        st.info("Warming up…")


# ── RIGHT: Camera feed ────────────────────────────────────────────────────────
with right:
    cam_placeholder = st.empty()

    if not engine.capture.is_camera_ok() and engine.capture.camera_error():
        cam_placeholder.error(f"Camera error:\n{engine.capture.camera_error()}")
    else:
        raw_frame = engine.latest_frame()
        if raw_frame is not None:
            if last:
                _draw_hud(raw_frame, last)
            frame_rgb = cv2.cvtColor(raw_frame, cv2.COLOR_BGR2RGB)
            cam_placeholder.image(frame_rgb, channels="RGB", use_container_width=True)
        else:
            cam_placeholder.info("📷 Waiting for camera…")


# ── Signal breakdown ──────────────────────────────────────────────────────────
st.divider()
st.markdown("#### Signal breakdown")
debug = engine.debug_info()

if debug:
    c1, c2, c3, c4, c5, c6 = st.columns(6)
    c1.metric("Head yaw",    f"{debug.get('head_yaw_deg', 0):.0f}°",
              help="±25° threshold for 'on screen'")
    c2.metric("EAR",         f"{((debug.get('ear_left',0)+debug.get('ear_right',0))/2):.3f}",
              help="Eye aspect ratio — <0.21 = blink")
    c3.metric("KPM norm",    f"{debug.get('kpm_norm', 0):.2f}",
              help="Keys per minute / 120")
    c4.metric("Mouse vel",   f"{debug.get('mouse_vel_norm', 0):.2f}",
              help="Mouse speed / 500 px/s")
    c5.metric("Mouse ent",   f"{debug.get('mouse_entropy', 0):.2f}",
              help="Path randomness — high = wandering")
    c6.metric("Posture",     f"{debug.get('posture_score', 0):.2f}",
              help="Head-over-shoulder ratio from Holistic")

    feat = engine.capture.get_latest_feature()
    if feat is not None:
        with st.expander("Raw feature vector (11 dims)"):
            labels = ["yaw","pitch","ear_L","ear_R","face",
                      "kpm","mv","ent","idle","gaze","posture"]
            fcols = st.columns(11)
            for i, (fc, lbl) in enumerate(zip(fcols, labels)):
                fc.metric(lbl, f"{feat[i]:.2f}")


# ── Score history ─────────────────────────────────────────────────────────────
if st.session_state.history:
    import pandas as pd

    st.divider()
    st.markdown("#### Score history")

    df = pd.DataFrame(st.session_state.history)
    df["time"] = pd.to_datetime(df["ts"], unit="s").dt.strftime("%H:%M:%S")

    st.line_chart(
        df.set_index("time")["score"],
        height=160,
        color="#1D9E75",
    )

    # Recent state timeline (last 20 epochs)
    recent = st.session_state.history[-20:]
    if recent:
        st.markdown("**Recent states**")
        tcols = st.columns(len(recent))
        for col, h in zip(tcols, recent):
            m = STATE_META.get(h["state"], STATE_META["warming_up"])
            col.markdown(
                f'<div style="text-align:center;font-size:1.1rem">{m["emoji"]}</div>'
                f'<div style="text-align:center;font-size:0.65rem;color:{m["color"]}">'
                f'{int(h["score"])}</div>',
                unsafe_allow_html=True,
            )


# ── Auto-refresh (macOS compatible — no extra package) ───────────────────────
# Streamlit re-runs the script on any widget interaction.
# For continuous refresh without interaction, we use a time-based approach.
refresh_rate = max(1.0, epoch_sec / 2)
time.sleep(0.8)
st.rerun()