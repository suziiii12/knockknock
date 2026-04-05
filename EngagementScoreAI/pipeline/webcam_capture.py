"""
pipeline/webcam_capture.py
---------------------------
macOS-compatible webcam capture thread using MediaPipe Tasks API.

macOS-specific notes:
  - Camera permission: macOS prompts automatically when cv2.VideoCapture opens.
    If denied, go to: System Settings → Privacy & Security → Camera → Terminal
  - We use CAP_AVFOUNDATION backend explicitly for reliability on macOS.
  - cv2.flip(frame, 1) mirrors the image for a natural selfie-view.
  - MediaPipe 0.10+ uses the new Tasks API (FaceLandmarker, PoseLandmarker).
    Model files are downloaded automatically on first use.
  - Threading uses daemon=True so threads die cleanly when the main process exits.
"""

import time
import threading
import platform
import os
from pathlib import Path
import numpy as np
from collections import deque
from dataclasses import dataclass, field
from typing import Optional, List, Tuple

import cv2
import mediapipe as mp
from mediapipe.tasks import python
from mediapipe.tasks.python import vision
from mediapipe import Image as MPImage

from pipeline.feature_extractor import FeatureExtractor, RawSignals


@dataclass
class BehavioralAccumulator:
    """Thread-safe accumulator for keyboard/mouse events between frames."""
    _lock: threading.Lock = field(default_factory=threading.Lock)
    keys_this_frame: int = 0
    mouse_positions: List[Tuple[float, float]] = field(default_factory=list)
    last_input_time: float = field(default_factory=time.time)

    def add_key(self):
        with self._lock:
            self.keys_this_frame += 1
            self.last_input_time = time.time()

    def add_mouse(self, x: float, y: float):
        with self._lock:
            self.mouse_positions.append((x, y))
            self.last_input_time = time.time()

    def flush(self) -> Tuple[int, List, float]:
        with self._lock:
            keys = self.keys_this_frame
            positions = self.mouse_positions.copy()
            last_t = self.last_input_time
            self.keys_this_frame = 0
            self.mouse_positions = []
        return keys, positions, last_t


def _open_camera(index: int) -> cv2.VideoCapture:
    """
    Open camera with the best backend for the current OS.
    On macOS, AVFoundation is more reliable than the default.
    """
    is_mac = platform.system() == "Darwin"

    if is_mac:
        cap = cv2.VideoCapture(index, cv2.CAP_AVFOUNDATION)
        if cap.isOpened():
            return cap
        # Fallback to default
        cap = cv2.VideoCapture(index)
    else:
        cap = cv2.VideoCapture(index)

    return cap


class WebcamCapture:
    """
    Background capture thread: opens webcam → MediaPipe → feature vectors.

    Parameters
    ----------
    fps         : target processing fps (10 = good balance for laptops)
    window_size : LSTM input window in frames (30 frames @ 10fps = 3s)
    camera_index: 0 = built-in FaceTime camera on MacBooks
    """

    _EAR_LEFT  = [362, 385, 387, 263, 373, 380]
    _EAR_RIGHT = [33, 160, 158, 133, 153, 144]

    _GAZE_ON_COLOR  = (0, 210, 90)
    _GAZE_OFF_COLOR = (60, 60, 230)

    def __init__(
        self,
        fps: int = 10,
        window_size: int = 30,
        camera_index: int = 0,
        behavioral: Optional[BehavioralAccumulator] = None,
    ):
        self.fps = fps
        self.window_size = window_size
        self.camera_index = camera_index
        self.behavioral = behavioral or BehavioralAccumulator()

        self._frame_buf: deque = deque(maxlen=window_size)
        self._latest_frame: Optional[np.ndarray] = None
        self._latest_debug: dict = {}

        self._running = False
        self._thread: Optional[threading.Thread] = None
        self._lock = threading.Lock()
        self._camera_ok = False
        self._error_msg = ""

        self.extractor = FeatureExtractor()

        self._face_landmarker = None
        self._pose_landmarker = None

    # ------------------------------------------------------------------ #
    #  Public API
    # ------------------------------------------------------------------ #

    def start(self):
        if self._running:
            return
        self._running = True
        self.extractor.reset()
        self._thread = threading.Thread(target=self._run, daemon=True, name="webcam-capture")
        self._thread.start()

    def stop(self):
        self._running = False
        if self._thread:
            self._thread.join(timeout=5.0)
        self._thread = None

    def get_window(self) -> Optional[np.ndarray]:
        with self._lock:
            if len(self._frame_buf) < self.window_size:
                return None
            return np.stack(list(self._frame_buf), axis=0).astype(np.float32)

    def get_latest_feature(self) -> Optional[np.ndarray]:
        with self._lock:
            if not self._frame_buf:
                return None
            return self._frame_buf[-1].copy()

    def get_frame(self) -> Optional[np.ndarray]:
        with self._lock:
            return self._latest_frame

    def get_debug_info(self) -> dict:
        with self._lock:
            return self._latest_debug.copy()

    def get_buffer_fill(self) -> float:
        with self._lock:
            return len(self._frame_buf) / self.window_size

    def is_camera_ok(self) -> bool:
        return self._camera_ok

    def camera_error(self) -> str:
        return self._error_msg

    def set_gaze_calibration(self, offset_x: float, offset_y: float):
        self.extractor.set_gaze_calibration(offset_x, offset_y)

    # ------------------------------------------------------------------ #
    #  Background thread
    # ------------------------------------------------------------------ #

    def _run(self):
        cap = _open_camera(self.camera_index)

        if not cap.isOpened():
            self._error_msg = (
                f"Cannot open camera {self.camera_index}.\n"
                "On macOS: System Settings → Privacy & Security → Camera → enable Terminal."
            )
            print(f"[WebcamCapture] ERROR: {self._error_msg}")
            self._running = False
            return

        # macOS: lower resolution is faster and sufficient for landmarks
        cap.set(cv2.CAP_PROP_FRAME_WIDTH, 640)
        cap.set(cv2.CAP_PROP_FRAME_HEIGHT, 480)
        cap.set(cv2.CAP_PROP_FPS, 30)
        self._camera_ok = True
        print(f"[WebcamCapture] Camera {self.camera_index} opened OK.")

        interval = 1.0 / self.fps

        # Download models if needed
        models_dir = Path("models")
        models_dir.mkdir(exist_ok=True)

        face_model_path = models_dir / "face_landmarker.task"
        pose_model_path = models_dir / "pose_landmarker_lite.task"

        if not face_model_path.exists():
            print("[WebcamCapture] Downloading face landmarker model...")
            import requests
            response = requests.get("https://storage.googleapis.com/mediapipe-models/face_landmarker/face_landmarker/float16/1/face_landmarker.task")
            with open(face_model_path, 'wb') as f:
                f.write(response.content)
            print("[WebcamCapture] Face model downloaded.")

        if not pose_model_path.exists():
            print("[WebcamCapture] Downloading pose landmarker model...")
            response = requests.get("https://storage.googleapis.com/mediapipe-models/pose_landmarker/pose_landmarker_lite/float16/1/pose_landmarker_lite.task")
            with open(pose_model_path, 'wb') as f:
                f.write(response.content)
            print("[WebcamCapture] Pose model downloaded.")

        # Create landmarkers
        face_options = vision.FaceLandmarkerOptions(
            base_options=python.BaseOptions(model_asset_path=str(face_model_path)),
            running_mode=vision.RunningMode.IMAGE,
            num_faces=1,
            min_face_detection_confidence=0.5,
            min_face_presence_confidence=0.5,
            min_tracking_confidence=0.5,
        )
        self._face_landmarker = vision.FaceLandmarker.create_from_options(face_options)

        pose_options = vision.PoseLandmarkerOptions(
            base_options=python.BaseOptions(model_asset_path=str(pose_model_path)),
            running_mode=vision.RunningMode.IMAGE,
            num_poses=1,
            min_pose_detection_confidence=0.5,
            min_pose_presence_confidence=0.5,
            min_tracking_confidence=0.5,
        )
        self._pose_landmarker = vision.PoseLandmarker.create_from_options(pose_options)

        print("[WebcamCapture] MediaPipe landmarkers initialized.")

        last_tick = time.time()

        try:
            while self._running:
                ret, frame = cap.read()
                if not ret:
                    time.sleep(0.05)
                    continue

                now = time.time()
                if now - last_tick < interval:
                    continue
                last_tick = now

                # Mirror horizontally — natural selfie view
                frame = cv2.flip(frame, 1)
                rgb = cv2.cvtColor(frame, cv2.COLOR_BGR2RGB)
                rgb.flags.writeable = False

                mp_image = MPImage(image_format=mp.ImageFormat.SRGB, data=rgb)

                face_result = self._face_landmarker.detect(mp_image)
                pose_result = self._pose_landmarker.detect(mp_image)

                rgb.flags.writeable = True
                annotated = cv2.cvtColor(rgb, cv2.COLOR_RGB2BGR)

                face_lms = None
                if face_result.face_landmarks:
                    face_lms = face_result.face_landmarks[0]
                    self._draw_face_overlay(annotated, face_lms)

                pose_lms = pose_result.pose_landmarks[0] if pose_result.pose_landmarks else None

                keys, mouse_pos, last_input_t = self.behavioral.flush()

                raw = RawSignals(
                    face_landmarks=face_lms,
                    pose_landmarks=pose_lms,
                    keys_this_second=keys,
                    mouse_positions=mouse_pos,
                    last_input_time=last_input_t,
                    current_time=now,
                )

                vec = self.extractor.extract(raw)

                with self._lock:
                    self._frame_buf.append(vec)
                    self._latest_frame = annotated.copy()
                    self._latest_debug = self._build_debug(vec, face_lms is not None)

        finally:
            cap.release()
            if self._face_landmarker:
                self._face_landmarker.close()
            if self._pose_landmarker:
                self._pose_landmarker.close()
            print("[WebcamCapture] Camera and landmarkers released.")

    def _draw_face_overlay(self, frame: np.ndarray, lms):
        h, w = frame.shape[:2]

        nose  = lms[1]
        l_eye = lms[33]
        r_eye = lms[263]
        eye_mid_x = (l_eye.x + r_eye.x) / 2
        yaw = (nose.x - eye_mid_x) * 180.0
        color = self._GAZE_ON_COLOR if abs(yaw) < 25 else self._GAZE_OFF_COLOR

        # Eye outlines
        for indices in [self._EAR_LEFT, self._EAR_RIGHT]:
            pts = [(int(lms[i].x * w), int(lms[i].y * h)) for i in indices]
            for i in range(len(pts)):
                cv2.line(frame, pts[i], pts[(i+1) % len(pts)], (180, 220, 255), 1)
            for pt in pts:
                cv2.circle(frame, pt, 2, (180, 220, 255), -1)

        # Nose dot (gaze indicator)
        cv2.circle(frame, (int(nose.x * w), int(nose.y * h)), 4, color, -1)

        # Face bounding hint
        fx1 = int(lms[454].x * w)
        fy1 = int(lms[10].y  * h)
        fx2 = int(lms[234].x * w)
        fy2 = int(lms[152].y * h)
        cv2.rectangle(frame, (fx1, fy1), (fx2, fy2), color, 1)

    def _build_debug(self, vec: np.ndarray, face_detected: bool) -> dict:
        return {
            "face_detected":   face_detected,
            "head_yaw_deg":    round(float(vec[0]) * 90, 1),
            "head_pitch_deg":  round(float(vec[1]) * 90, 1),
            "ear_left":        round(float(vec[2]), 3),
            "ear_right":       round(float(vec[3]), 3),
            "kpm_norm":        round(float(vec[5]), 3),
            "mouse_vel_norm":  round(float(vec[6]), 3),
            "mouse_entropy":   round(float(vec[7]), 3),
            "idle_norm":       round(float(vec[8]), 3),
            "gaze_score":      round(float(vec[9]), 3),
            "posture_score":   round(float(vec[10]), 3),
        }