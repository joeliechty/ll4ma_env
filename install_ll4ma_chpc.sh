#!/bin/bash
set -e

echo "Starting ll4ma environment setup (CHPC)..."

REPO_DIR="/scratch/general/vast/$USER/latent_dynamics"

# 1. Create or update the Conda environment
echo "Creating/updating conda environment 'll4ma' from environment.yml..."
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
NEW_SUM=$(md5sum "$SCRIPT_DIR/environment.yml" | cut -d ' ' -f 1)
OLD_SUM=$([ -f "$SCRIPT_DIR/.env_checksum" ] && cat "$SCRIPT_DIR/.env_checksum" || echo "")

if [ "$NEW_SUM" != "$OLD_SUM" ]; then
    echo "Changes detected in environment.yml. Updating..."
    conda env update -f "$SCRIPT_DIR/environment.yml" --prune
    echo "$NEW_SUM" > "$SCRIPT_DIR/.env_checksum"
else
    echo "environment.yml is unchanged. Skipping update to save time."
fi

# 2. Activate the Conda environment
echo "Activating 'll4ma' environment..."
eval "$(conda shell.bash hook)"
conda activate ll4ma

# 3. CHPC is Linux/CUDA only — install real torch-scatter with CUDA support
echo "Installing torch-scatter (CUDA, Linux/CHPC)..."
pip install torch-scatter -f https://data.pyg.org/whl/torch-2.2.0+cu118.html

# 4. Link ll4ma packages via .pth file (bypasses ROS/Catkin setup.py)
echo "Linking ll4ma packages via Python (.pth files)..."
SITE_PACKAGES=$(python -c "import site; print(site.getsitepackages()[0])")
PTH_FILE="$SITE_PACKAGES/ll4ma.pth"

echo "$REPO_DIR/ll4ma_util/src" > "$PTH_FILE"
echo "$REPO_DIR/ll4ma_relation/src" >> "$PTH_FILE"
echo "$REPO_DIR/ll4ma_tamp/blind_grasping/src" >> "$PTH_FILE"
echo "$REPO_DIR/multisensory_learning/src" >> "$PTH_FILE"

echo "==========================================================="
echo "Installation complete!"
echo "Your 'll4ma' environment is ready and your local packages"
echo "are linked natively without using ROS/Catkin."
echo "Repo root: $REPO_DIR"
echo "==========================================================="
