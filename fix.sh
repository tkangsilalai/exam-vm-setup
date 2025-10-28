#!/usr/bin/env bash
# =============================================================
# Fix Jupyter "ExtendedCompletionFinder" / kernel startup errors
# for the 'dsde' Conda environment on Linux Mint
# =============================================================

set -euo pipefail

echo "[1/5] Activating conda environment..."
# Ensure conda is loaded
if [ -f "$HOME/miniconda3/etc/profile.d/conda.sh" ]; then
    source "$HOME/miniconda3/etc/profile.d/conda.sh"
else
    echo "❌ Could not find conda.sh in ~/miniconda3/etc/profile.d/"
    exit 1
fi

# Activate dsde env
conda activate dsde || { echo "❌ Failed to activate env 'dsde'"; exit 1; }

echo "[2/5] Uninstalling conflicting packages..."
python -m pip uninstall -y argcomplete prompt_toolkit ipython ipykernel jupyter_client traitlets jupyter_core || true

echo "[3/5] Installing stable compatible versions..."
python -m pip install --no-cache-dir \
  "ipython==8.26.0" \
  "prompt_toolkit==3.0.43" \
  "argcomplete==3.1.6" \
  "ipykernel==6.29.5" \
  "jupyter_client==8.6.2" \
  "jupyter_core==5.7.2" \
  "traitlets==5.14.3"

echo "[4/5] Registering Jupyter kernel..."
python -m ipykernel install --user --name dsde --display-name "Python (dsde)"

echo "[5/5] Cleaning up potential IPython configs..."
rm -rf "$HOME/.ipython/profile_default/startup"/* 2>/dev/null || true
rm -f "$HOME/.ipython/profile_default/ipython_config.py" 2>/dev/null || true

echo
echo "✅ Done! Now restart VS Code and select the 'Python (dsde)' kernel."
echo "   Test by opening a .ipynb file and running:"
echo "       import IPython, prompt_toolkit; print('OK')"
