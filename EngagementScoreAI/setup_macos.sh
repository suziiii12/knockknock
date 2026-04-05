#!/bin/bash
# setup_macos.sh
# One-shot setup script for macOS
# Run: bash setup_macos.sh

set -e

echo "================================================"
echo "  Focus Score Pipeline — macOS Setup"
echo "================================================"

# Check Python version
PYTHON=$(which python3)
PYVER=$($PYTHON --version 2>&1 | awk '{print $2}')
echo "Python: $PYVER at $PYTHON"

MAJOR=$(echo $PYVER | cut -d. -f1)
MINOR=$(echo $PYVER | cut -d. -f2)
if [ "$MAJOR" -lt 3 ] || ([ "$MAJOR" -eq 3 ] && [ "$MINOR" -lt 9 ]); then
  echo "ERROR: Python 3.9+ required. Install via: brew install python@3.11"
  exit 1
fi

# Create venv
if [ ! -d "venv" ]; then
  echo ""
  echo "Creating virtual environment..."
  $PYTHON -m venv venv
fi

source venv/bin/activate
echo "venv activated: $(which python)"

# Upgrade pip
pip install --upgrade pip --quiet

# Install dependencies
echo ""
echo "Installing dependencies..."
pip install -r requirements.txt

# Generate weights
echo ""
echo "Generating model weights..."
python download_weights.py

echo ""
echo "================================================"
echo "  Setup complete!"
echo ""
echo "  PERMISSIONS NEEDED ON macOS:"
echo "  1. Camera (auto-prompted on first run)"
echo "  2. Accessibility for KPM tracking:"
echo "     System Settings → Privacy & Security"
echo "     → Accessibility → add Terminal / iTerm2"
echo ""
echo "  RUN:"
echo "    source venv/bin/activate"
echo "    streamlit run app.py"
echo "================================================"
