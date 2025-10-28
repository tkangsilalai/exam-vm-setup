#!/usr/bin/env bash
# =============================================================
# Fix Jupyter "ExtendedCompletionFinder", Streamlit TypeAlias error,
# and packaging/version mismatches for the 'dsde' Conda environment
# on Linux Mint or similar systems.
# =============================================================

set -euo pipefail

echo "[1/9] Activating conda environment..."
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
echo "[3/9] Reinstalling packaging and dependencies..."
python -m pip uninstall -y packaging || true
python -m pip install --no-cache-dir "packaging==24.1"
python -m pip install -U pyparsing ipykernel jupyter_client traitlets tornado

# -------------------------------------------------------------
# Fix for 'TypeAlias' import error (Python 3.12 compatibility)
# -------------------------------------------------------------
echo "[4/9] Ensuring typing_extensions compatibility..."
python -m pip install --upgrade --no-cache-dir "typing_extensions>=4.11.0"

# -------------------------------------------------------------
# IPython / Jupyter kernel fixes
# -------------------------------------------------------------
echo "[5/9] Uninstalling conflicting Jupyter packages..."
python -m pip uninstall -y argcomplete prompt_toolkit ipython ipykernel jupyter_client traitlets jupyter_core || true

echo "[6/9] Installing stable compatible versions..."
python -m pip install --no-cache-dir \
  "ipython==8.26.0" \
  "prompt_toolkit==3.0.43" \
  "argcomplete==3.1.6" \
  "ipykernel==6.29.5" \
  "jupyter_client==8.6.2" \
  "jupyter_core==5.7.2" \
  "traitlets==5.14.3"

echo "[7/9] Registering Jupyter kernel..."
python -m ipykernel install --user --name dsde --display-name "Python (dsde)"

echo "[8/9] Cleaning up potential IPython configs..."
rm -rf "$HOME/.ipython/profile_default/startup"/* 2>/dev/null || true
rm -f "$HOME/.ipython/profile_default/ipython_config.py" 2>/dev/null || true

# -------------------------------------------------------------
# Streamlit + Py3.12 compatible stack
# -------------------------------------------------------------
echo "[9/9] Reinstalling Streamlit stack (Py3.12 compatible)..."
python -m pip install --no-cache-dir \
  "streamlit==1.39.0" \
  "numpy<2" \
  "protobuf<6" \
  "pyarrow>=17" \
  "altair>=5.3" \
  "pandas>=2.2.2"

# -------------------------------------------------------------
# Verification
# -------------------------------------------------------------


# -------------------------------------------------------------
# Ensure pip and base Streamlit are available via conda
# -------------------------------------------------------------
echo "[2/9] Installing pip and Streamlit base from conda-forge..."
conda install -n dsde -y pip
conda install -c conda-forge -y streamlit

python - <<'PY'
print("🔍 Verifying modules ...")
import IPython, prompt_toolkit, argcomplete, jupyter_client, streamlit, packaging, typing_extensions
print(f"✅ OK!\n"
      f"  IPython={IPython.__version__}\n"
      f"  prompt_toolkit={prompt_toolkit.__version__}\n"
      f"  Streamlit={streamlit.__version__}\n"
      f"  Packaging={packaging.__version__}\n"
      f"  typing_extensions={typing_extensions.__version__}")
PY

echo
echo "✅ Done! Please restart VS Code and select the 'Python (dsde)' kernel."
echo "   Test by opening a .ipynb file and running any cell."
