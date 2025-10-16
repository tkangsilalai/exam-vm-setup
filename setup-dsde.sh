#!/usr/bin/env bash
# ===================================================
# Simple DSDE environment setup script
# Linux Mint / Ubuntu-based
# ===================================================

# Source conda
source ~/miniconda3/bin/activate
conda activate dsde

echo "✅ Activated conda environment: dsde"

# Install all required packages
pip install --upgrade pip

echo "📦 Installing required packages..."

pip install \
    beautifulsoup4 selenium \
    matplotlib seaborn plotly streamlit \
    fastapi "apache-airflow" \
    kafka-python-ng pymongo \
    pandasql sqlite-utils

echo "✅ Installation complete!"
echo "🔍 Verifying key imports..."

python - <<'EOF'
import importlib
modules = [
    "bs4", "selenium",
    "matplotlib.pyplot", "seaborn", "plotly", "streamlit",
    "fastapi", "airflow",
    "kafka", "pymongo",
    "pandasql", "sqlite3"
]
for m in modules:
    try:
        importlib.import_module(m)
        print(f"✅ {m} imported successfully")
    except Exception as e:
        print(f"❌ {m} failed: {e}")
EOF

echo "🎉 DSDE environment setup finished!"
