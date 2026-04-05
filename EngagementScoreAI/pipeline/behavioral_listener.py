"""
pipeline/behavioral_listener.py
---------------------------------
macOS-compatible keyboard and mouse listener using pynput.

macOS requirements:
  - Terminal (or your IDE) needs Accessibility permission:
    System Settings → Privacy & Security → Accessibility → add Terminal / iTerm2
  - Without this permission, keyboard listener silently fails.
    Mouse movement still works without it.
  - We handle this gracefully: if listeners fail, behavioral features
    default to neutral values rather than crashing.

Privacy: key characters are NEVER recorded — only press count per frame.
"""

import time
import threading
from typing import Optional, Tuple


def start_listeners(behavioral_accumulator) -> Tuple[Optional[object], Optional[object]]:
    """
    Start keyboard and mouse listeners.
    On macOS, this requires Accessibility permission for keyboard events.
    Returns (kb_listener, ms_listener) — call .stop() on each to clean up.
    """
    kb_listener = _start_keyboard_listener(behavioral_accumulator)
    ms_listener = _start_mouse_listener(behavioral_accumulator)
    return kb_listener, ms_listener


def _start_keyboard_listener(acc) -> Optional[object]:
    try:
        from pynput import keyboard

        listener = keyboard.Listener(
            on_press=lambda key: _safe_add_key(acc),
            suppress=False,
        )
        listener.start()

        # On macOS without Accessibility permission, the listener starts
        # but silently receives no events. We can't detect this easily,
        # so we just warn the user.
        print("[BehavioralListener] Keyboard listener started.")
        print("  If KPM stays 0, grant Accessibility permission:")
        print("  System Settings → Privacy & Security → Accessibility → add Terminal")
        return listener

    except Exception as e:
        print(f"[BehavioralListener] Keyboard listener failed: {e}")
        print("  KPM feature will be unavailable.")
        return None


def _start_mouse_listener(acc) -> Optional[object]:
    """Mouse movement does NOT require Accessibility on macOS."""
    try:
        from pynput import mouse

        def on_move(x, y):
            acc.add_mouse(float(x), float(y))

        def on_click(x, y, button, pressed):
            if pressed:
                _safe_add_key(acc)

        listener = mouse.Listener(on_move=on_move, on_click=on_click)
        listener.start()
        print("[BehavioralListener] Mouse listener started.")
        return listener

    except Exception as e:
        print(f"[BehavioralListener] Mouse listener failed: {e}")
        return None


def _safe_add_key(acc):
    try:
        acc.add_key()
    except Exception:
        pass


def stop_listeners(kb_listener, ms_listener):
    for lst in [kb_listener, ms_listener]:
        if lst is not None:
            try:
                lst.stop()
            except Exception:
                pass

