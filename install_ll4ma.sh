#!/bin/bash
set -e

echo "Starting ll4ma environment setup..."

# 1. Create or update the Conda environment
echo "Creating/updating conda environment 'll4ma' from environment.yml..."
conda env update -f environment.yml --prune

# 2. Activate the Conda environment
echo "Activating 'll4ma' environment..."
eval "$(conda shell.bash hook)"
conda activate ll4ma

# 3. OS Detection for hardware-accelerated PyTorch
echo "Detecting Operating System for hardware-specific installations..."
OS="$(uname)"
if [ "$OS" = "Darwin" ]; then
    echo "macOS detected. Installing PyTorch (MPS)..."
    pip install torch torchvision torchaudio
    
    echo "Injecting dummy modules for macOS compatibility..."
    SITE_PACKAGES=$(python -c "import site; print(site.getsitepackages()[0])")
    
    # 1. Handle spconv (from our previous step)
    mkdir -p "$SITE_PACKAGES/spconv"
    touch "$SITE_PACKAGES/spconv/__init__.py"
    cat << 'EOF' > "$SITE_PACKAGES/spconv/pytorch.py"
import sys
from unittest.mock import MagicMock
sys.modules[__name__] = MagicMock()
EOF

    # 2. NEW: Handle torch_scatter
    # This creates a fake torch_scatter that returns mocks for everything
    mkdir -p "$SITE_PACKAGES/torch_scatter"
    cat << 'EOF' > "$SITE_PACKAGES/torch_scatter/__init__.py"
import sys
from unittest.mock import MagicMock
sys.modules[__name__] = MagicMock()
EOF

elif [ "$OS" = "Linux" ]; then
    # ... your existing Linux CUDA install logic ...
    # On Linux, we install the real version with CUDA support:
    pip install torch-scatter -f https://data.pyg.org/whl/torch-2.2.0+cu118.html
fi

# 4. Bypass ROS setup.py using a .pth file
echo "Linking ll4ma packages purely via Python (.pth files)..."

# Find the active environment's site-packages directory
SITE_PACKAGES=$(python -c "import site; print(site.getsitepackages()[0])")

# Create a custom .pth file for the ll4ma packages
PTH_FILE="$SITE_PACKAGES/ll4ma.pth"

# Get the current working directory (assuming you run this from your git workspace root)
REPO_DIR="$HOME/git_repos"

# Write the path to the actual python source directory directly into the environment
echo "$REPO_DIR/ll4ma_util/src" > "$PTH_FILE"
echo "$REPO_DIR/ll4ma_relation/src" >> "$PTH_FILE"
echo "$REPO_DIR/ll4ma_tamp/blind_grasping/src" >> "$PTH_FILE"
echo "$REPO_DIR/multisensory_learning/src" >> "$PTH_FILE"

# If you have other packages in this workspace that also fail to install, 
# you can link them identically by uncommenting/adding lines below:
# echo "$REPO_DIR/ll4ma_relation/src" >> "$PTH_FILE"
# echo "$REPO_DIR/blind_grasping/src" >> "$PTH_FILE"

echo "==========================================================="
echo "Installation complete!"
echo "Your 'll4ma' environment is ready and your local packages"
echo "are linked natively without using ROS/Catkin."
echo "==========================================================="