"""
pipeline/feature_extractor.py
------------------------------
Converts raw MediaPipe landmark output into the 11-dimensional normalised
feature vector consumed by EngagementLSTM every frame.

Feature vector layout (indices):
  0  head_yaw_norm       [-1, 1]   left/right head rotation
  1  head_pitch_norm     [-1, 1]   up/down head rotation
  2  ear_left            [0, 1]    left eye aspect ratio
  3  ear_right           [0, 1]    right eye aspect ratio
  4  face_present        {0, 1}    face detected this frame
  5  kpm_norm            [0, 1]    keys per minute / 120
  6  mouse_vel_norm      [0, 1]    mouse velocity / 500 px/s
  7  mouse_entropy       [0, 1]    path randomness (Shannon entropy)
  8  idle_norm           [0, 1]    idle seconds / 30
  9  gaze_score_norm     [0, 1]    fraction of time gaze on screen (rolling)
  10 posture_score_norm  [0, 1]    shoulder/neck alignment from Holistic
"""

import math
import numpy as np
from collections import deque
from dataclasses import dataclass, field
from typing import Optional, List, Tuple


@dataclass
class RawSignals:
    """Container for one frame's raw measurements."""
    # Vision
    face_landmarks: Optional[object] = None      # MediaPipe FaceMesh landmarks
    pose_landmarks: Optional[object] = None      # MediaPipe Holistic pose

    # Behavioral (accumulated between frames)
    keys_this_second: int = 0
    mouse_positions: List[Tuple[float, float]] = field(default_factory=list)
    last_input_time: float = 0.0
    current_time: float = 0.0


class FeatureExtractor:
    """
    Stateful feature extractor. Call `extract(raw)` once per frame.
    Maintains rolling buffers for temporal features.
    """

    # MediaPipe FaceMesh landmark indices
    # Eye aspect ratio landmarks (same indices used in the pipeline module)
    _EAR_LEFT  = [362, 385, 387, 263, 373, 380]
    _EAR_RIGHT = [33, 160, 158, 133, 153, 144]

    # Head pose reference points (nose tip, chin, eye corners, mouth corners)
    _POSE_POINTS = {
        "nose_tip":    1,
        "chin":        152,
        "left_eye":    33,
        "right_eye":   263,
        "left_mouth":  61,
        "right_mouth": 291,
    }

    # Holistic pose landmarks for posture
    _SHOULDER_LEFT  = 11
    _SHOULDER_RIGHT = 12
    _EAR_LEFT_POSE  = 7
    _EAR_RIGHT_POSE = 8

    def __init__(
        self,
        gaze_history_len: int = 30,
        kpm_history_len: int = 60,     # 1-minute rolling KPM
        mouse_pos_buf_len: int = 20,
        max_idle_sec: float = 30.0,
        max_kpm: float = 120.0,
        max_mouse_vel: float = 500.0,
        yaw_threshold_deg: float = 25.0,
    ):
        self.max_idle_sec = max_idle_sec
        self.max_kpm = max_kpm
        self.max_mouse_vel = max_mouse_vel
        self.yaw_threshold_deg = yaw_threshold_deg

        # Rolling buffers
        self._gaze_history = deque(maxlen=gaze_history_len)
        self._kpm_buffer = deque(maxlen=kpm_history_len)  # keys per second
        self._mouse_pos_buf = deque(maxlen=mouse_pos_buf_len)
        self._mouse_time_buf = deque(maxlen=mouse_pos_buf_len)

        # Blink state
        self._prev_ear = 1.0
        self._blink_count = 0

        # Calibration offset (set during calibration step)
        self._gaze_offset_x = 0.0
        self._gaze_offset_y = 0.0

    # ------------------------------------------------------------------ #
    #  Public API
    # ------------------------------------------------------------------ #

    def extract(self, raw: RawSignals) -> np.ndarray:
        """Extract 11-dim feature vector from one frame's raw signals."""
        vec = np.zeros(11, dtype=np.float32)

        if raw.face_landmarks is not None:
            lms = raw.face_landmarks
            yaw, pitch = self._head_pose(lms)
            ear_l, ear_r = self._ear(lms)
            gaze_on = abs(yaw) < self.yaw_threshold_deg
            self._gaze_history.append(float(gaze_on))

            # Blink detection
            ear = (ear_l + ear_r) / 2
            if ear < 0.21 and self._prev_ear >= 0.21:
                self._blink_count += 1
            self._prev_ear = ear

            vec[0] = np.clip(yaw / 90.0, -1.0, 1.0)
            vec[1] = np.clip(pitch / 90.0, -1.0, 1.0)
            vec[2] = np.clip(ear_l, 0.0, 1.0)
            vec[3] = np.clip(ear_r, 0.0, 1.0)
            vec[4] = 1.0
        else:
            self._gaze_history.append(0.0)
            vec[4] = 0.0

        # Behavioral features
        kps = raw.keys_this_second
        self._kpm_buffer.append(kps)
        kpm = sum(self._kpm_buffer) * (60.0 / max(len(self._kpm_buffer), 1))
        vec[5] = np.clip(kpm / self.max_kpm, 0.0, 1.0)

        mouse_vel, mouse_ent = self._mouse_features(
            raw.mouse_positions, raw.current_time
        )
        vec[6] = np.clip(mouse_vel / self.max_mouse_vel, 0.0, 1.0)
        vec[7] = np.clip(mouse_ent, 0.0, 1.0)

        idle_sec = max(0.0, raw.current_time - raw.last_input_time)
        vec[8] = np.clip(idle_sec / self.max_idle_sec, 0.0, 1.0)

        gaze_score = (
            np.mean(self._gaze_history) if self._gaze_history else 0.5
        )
        vec[9] = float(gaze_score)

        posture = self._posture_score(raw.pose_landmarks)
        vec[10] = posture

        return vec

    def reset(self):
        """Clear rolling buffers (call at session start)."""
        self._gaze_history.clear()
        self._kpm_buffer.clear()
        self._mouse_pos_buf.clear()
        self._mouse_time_buf.clear()
        self._prev_ear = 1.0
        self._blink_count = 0

    @property
    def blink_count(self) -> int:
        return self._blink_count

    def set_gaze_calibration(self, offset_x: float, offset_y: float):
        self._gaze_offset_x = offset_x
        self._gaze_offset_y = offset_y

    # ------------------------------------------------------------------ #
    #  Private helpers
    # ------------------------------------------------------------------ #

    def _ear(self, lms) -> Tuple[float, float]:
        """Eye Aspect Ratio for blink / drowsiness detection."""
        def _compute(indices):
            pts = [lms[i] for i in indices]
            def dist(a, b):
                return math.hypot(a.x - b.x, a.y - b.y)
            vertical = dist(pts[1], pts[5]) + dist(pts[2], pts[4])
            horizontal = dist(pts[0], pts[3])
            return vertical / (2.0 * horizontal + 1e-6)
        return _compute(self._EAR_LEFT), _compute(self._EAR_RIGHT)

    def _head_pose(self, lms) -> Tuple[float, float]:
        """
        Estimate head yaw and pitch from facial landmarks.
        Uses nose-to-eye-midpoint vector as a proxy for gaze direction.
        Returns (yaw_deg, pitch_deg).
        """
        nose  = lms[self._POSE_POINTS["nose_tip"]]
        l_eye = lms[self._POSE_POINTS["left_eye"]]
        r_eye = lms[self._POSE_POINTS["right_eye"]]
        chin  = lms[self._POSE_POINTS["chin"]]

        eye_mid_x = (l_eye.x + r_eye.x) / 2
        eye_mid_y = (l_eye.y + r_eye.y) / 2

        # Yaw: horizontal deviation of nose from eye midpoint
        yaw_norm  = (nose.x - eye_mid_x) * 2.0   # normalised [-1, 1]
        yaw_deg   = yaw_norm * 90.0

        # Pitch: vertical deviation (nose vs chin midpoint with eye)
        face_height = abs(chin.y - eye_mid_y) + 1e-6
        pitch_norm  = (nose.y - eye_mid_y) / face_height - 0.5
        pitch_deg   = pitch_norm * 90.0

        return yaw_deg, pitch_deg

    def _mouse_features(
        self,
        new_positions: List[Tuple[float, float]],
        current_time: float,
    ) -> Tuple[float, float]:
        """
        Compute mouse velocity (px/s) and path entropy from recent positions.
        """
        for pos in new_positions:
            self._mouse_pos_buf.append(pos)
            self._mouse_time_buf.append(current_time)

        positions = list(self._mouse_pos_buf)
        times = list(self._mouse_time_buf)

        if len(positions) < 2:
            return 0.0, 0.0

        # Velocity
        total_dist = sum(
            math.hypot(
                positions[i][0] - positions[i-1][0],
                positions[i][1] - positions[i-1][1]
            )
            for i in range(1, len(positions))
        )
        dt = max(times[-1] - times[0], 0.1)
        velocity = total_dist / dt

        # Path entropy (direction change distribution)
        entropy = self._path_entropy(positions)

        return velocity, entropy

    @staticmethod
    def _path_entropy(positions: List[Tuple[float, float]]) -> float:
        """
        Shannon entropy of direction-change angles along mouse path.
        High = random wandering. Low = purposeful straight movements.
        """
        if len(positions) < 3:
            return 0.0

        angles = []
        for i in range(1, len(positions) - 1):
            v1 = np.array(positions[i])   - np.array(positions[i-1])
            v2 = np.array(positions[i+1]) - np.array(positions[i])
            n1, n2 = np.linalg.norm(v1), np.linalg.norm(v2)
            if n1 < 1e-6 or n2 < 1e-6:
                continue
            cos_a = np.dot(v1, v2) / (n1 * n2)
            angles.append(np.arccos(np.clip(cos_a, -1.0, 1.0)))

        if not angles:
            return 0.0

        hist, _ = np.histogram(angles, bins=8, range=(0, math.pi), density=True)
        hist = hist + 1e-8
        entropy = -np.sum(hist * np.log(hist))
        max_entropy = math.log(8)
        return float(np.clip(entropy / max_entropy, 0.0, 1.0))

    def _posture_score(self, pose_landmarks) -> float:
        """
        Estimate upright posture from Holistic pose landmarks.
        Returns 1.0 for perfect posture, 0.0 for slouching.
        """
        if pose_landmarks is None:
            return 0.5  # unknown

        try:
            lms = pose_landmarks.landmark
            ls = lms[self._SHOULDER_LEFT]
            rs = lms[self._SHOULDER_RIGHT]
            le = lms[self._EAR_LEFT_POSE]
            re = lms[self._EAR_RIGHT_POSE]

            # Shoulder symmetry: how level are the shoulders?
            shoulder_tilt = abs(ls.y - rs.y) * 10.0  # 0 = level

            # Head height over shoulders: low head = slouching
            ear_mid_y = (le.y + re.y) / 2
            shoulder_mid_y = (ls.y + rs.y) / 2
            head_over_shoulder = shoulder_mid_y - ear_mid_y  # positive = head above

            # Normalise: typical range 0.05 – 0.3
            posture = np.clip(head_over_shoulder / 0.25, 0.0, 1.0)
            posture *= (1.0 - min(shoulder_tilt, 1.0) * 0.3)

            return float(posture)
        except (IndexError, AttributeError):
            return 0.5
