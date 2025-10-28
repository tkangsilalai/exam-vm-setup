#!/usr/bin/env bash
# =============================================================
# Fix Jupyter "ExtendedCompletionFinder" / kernel startup errors
# for the 'dsde' Conda environment on Linux Mint
# =============================================================

set -euo pipefail

echo "[1/7] Activating conda environment..."
# Ensure conda is available
if [ -f "$HOME/miniconda3/etc/profile.d/conda.sh" ]; then
    source "$HOME/miniconda3/etc/profile.d/conda.sh"
else
    echo "❌ Could not find conda.sh in ~/miniconda3/etc/profile.d/"
    exit 1
fi

# Activate dsde env
conda activate dsde || { echo "❌ Failed to activate env 'dsde'"; exit 1; }

echo "[2/7] Uninstalling conflicting packages..."
python -m pip uninstall -y argcomplete prompt_toolkit ipython ipykernel jupyter_client traitlets jupyter_core || true

echo "[3/7] Installing stable compatible versions..."
python -m pip install --no-cache-dir \
  "ipython==8.26.0" \
  "prompt_toolkit==3.0.43" \
  "argcomplete==3.1.6" \
  "ipykernel==6.29.5" \
  "jupyter_client==8.6.2" \
  "jupyter_core==5.7.2" \
  "traitlets==5.14.3"

echo "[4/7] Registering Jupyter kernel..."
python -m ipykernel install --user --name dsde --display-name "Python (dsde)"

echo "[5/7] Cleaning up potential IPython configs..."
rm -rf "$HOME/.ipython/profile_default/startup"/* 2>/dev/null || true
rm -f "$HOME/.ipython/profile_default/ipython_config.py" 2>/dev/null || true

echo "[6/7] Optional: reinstall Streamlit stack to avoid runtime issues..."
python -m pip install --no-cache-dir \
  "numpy<2" \
  "protobuf<6" \
  "altair<6" \
  "pyarrow==17.*" \
  "streamlit==1.37.1" \
  "click>=8,<9" "watchdog" "blinker" "rich"

echo "[7/7] Verifying environment imports..."
python - <<'PY'
print("🔍 Verifying modules ...")
import IPython, prompt_toolkit, argcomplete, jupyter_client, streamlit
print(f"✅ All good!\n  IPython={IPython.__version__}\n  prompt_toolkit={prompt_toolkit.__version__}\n  Streamlit={streamlit.__version__}")
PY

echo
echo "✅ Done! Please restart VS Code and select the 'Python (dsde)' kernel."
echo "   Test by opening a .ipynb file and running any cell."
