from importlib.util import module_from_spec, spec_from_file_location
from pathlib import Path
import sys

BACKEND_DIR = Path(__file__).resolve().parent / "backend"
BACKEND_MAIN = BACKEND_DIR / "main.py"

if str(BACKEND_DIR) not in sys.path:
    sys.path.insert(0, str(BACKEND_DIR))

_spec = spec_from_file_location("backend_main", BACKEND_MAIN)
if _spec is None or _spec.loader is None:
    raise RuntimeError(f"Unable to load backend app from {BACKEND_MAIN}")

_backend_main = module_from_spec(_spec)
_spec.loader.exec_module(_backend_main)

app = _backend_main.app
