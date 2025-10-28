#!/usr/bin/env bash
# =============================================================
# Fix Jupyter "ExtendedCompletionFinder" / kernel startup errors
# and Streamlit / packaging version mismatches
# for the 'dsde' Conda environment on Linux Mint
# =============================================================

set -euo pipefail

echo "[1/8] Activating conda environment..."
# Ensure conda is available
if [ -f "$HOME/miniconda3/etc/profile.d/conda.sh" ]; then
    source "$HOME/miniconda3/etc/profile.d/conda.sh"
else
    echo "❌ Could not find conda.sh in ~/miniconda3/etc/profile.d/"
    exit 1
fi

# Activate dsde env
conda activate dsde || { echo "❌ Failed to activate env 'dsde'"; exit 1; }

# -------------------------------------------------------------
# Packaging + dependency fixes
# -------------------------------------------------------------
echo "[2/8] Reinstalling packaging and dependencies..."
python -m pip uninstall -y packaging || true
python -m pip install --no-cache-dir "packaging==24.1"
python -m pip install -U pyparsing ipykernel jupyter_client traitlets tornado

# -------------------------------------------------------------
# IPython / Jupyter kernel fixes
# -------------------------------------------------------------
echo "[3/8] Uninstalling conflicting Jupyter packages..."
python -m pip uninstall -y argcomplete prompt_toolkit ipython ipykernel jupyter_client traitlets jupyter_core || true

echo "[4/8] Installing stable compatible versions..."
python -m pip install --no-cache-dir \
  "ipython==8.26.0" \
  "prompt_toolkit==3.0.43" \
  "argcomplete==3.1.6" \
  "ipykernel==6.29.5" \
  "jupyter_client==8.6.2" \
  "jupyter_core==5.7.2" \
  "traitlets==5.14.3"

echo "[5/8] Registering Jupyter kernel..."
python -m ipykernel install --user --name dsde --display-name "Python (dsde)"

echo "[6/8] Cleaning up potential IPython configs..."
rm -rf "$HOME/.ipython/profile_default/startup"/* 2>/dev/null || true
rm -f "$HOME/.ipython/profile_default/ipython_config.py" 2>/dev/null || true

# -------------------------------------------------------------
# Streamlit stack (optional but recommended)
# -------------------------------------------------------------
echo "[7/8] Reinstalling Streamlit and dependencies..."
python -m pip install --no-cache-dir \
  "numpy<2" \
  "protobuf<6" \
  "altair<6" \
  "pyarrow==17.*" \
  "streamlit==1.37.1" \
  "click>=8,<9" "watchdog" "blinker" "rich"

# -------------------------------------------------------------
# Verification
# -------------------------------------------------------------
echo "[8/8] Verifying key imports..."
python - <<'PY'
print("🔍 Verifying modules ...")
import IPython, prompt_toolkit, argcomplete, jupyter_client, streamlit, packaging
print(f"✅ OK!\n  IPython={IPython.__version__}\n  prompt_toolkit={prompt_toolkit.__version__}\n  Streamlit={streamlit.__version__}\n  Packaging={packaging.__version__}")
PY

echo
echo "✅ Done! Please restart VS Code and select the 'Python (dsde)' kernel."
echo "   Test by opening a .ipynb file and running any cell."
