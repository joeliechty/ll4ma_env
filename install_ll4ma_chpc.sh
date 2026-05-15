#!/bin/bash
set -e

echo "Starting ll4ma environment setup (CHPC)..."

REPO_DIR="/scratch/general/vast/$USER/latent_dynamics"
ENVS_DIR="/scratch/general/vast/$USER/conda_envs"
ENV_PREFIX="$ENVS_DIR/ll4ma"

# Ensure scratch envs dir exists and is registered with conda so `conda activate ll4ma`
# resolves to the scratch path (faster VAST filesystem vs. NFS home).
mkdir -p "$ENVS_DIR"
if ! conda config --show envs_dirs 2>/dev/null | grep -qF "$ENVS_DIR"; then
    echo "Registering $ENVS_DIR in conda envs_dirs..."
    conda config --add envs_dirs "$ENVS_DIR"
fi

# 1. Create or update the Conda environment (in scratch)
echo "Creating/updating conda environment at $ENV_PREFIX..."
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
NEW_SUM=$(md5sum "$SCRIPT_DIR/environment.yml" | cut -d ' ' -f 1)
OLD_SUM=$([ -f "$SCRIPT_DIR/.env_checksum" ] && cat "$SCRIPT_DIR/.env_checksum" || echo "")

if [ "$NEW_SUM" != "$OLD_SUM" ]; then
    if [ -d "$ENV_PREFIX" ]; then
        echo "Changes detected in environment.yml. Updating existing env (no --prune)..."
        conda env update -p "$ENV_PREFIX" -f "$SCRIPT_DIR/environment.yml"
    else
        echo "No existing env at $ENV_PREFIX. Creating fresh from environment.yml..."
        conda env create -p "$ENV_PREFIX" -f "$SCRIPT_DIR/environment.yml"
    fi
    echo "$NEW_SUM" > "$SCRIPT_DIR/.env_checksum"
else
    echo "environment.yml is unchanged. Skipping update to save time."
fi

# 2. Activate the Conda environment
echo "Activating 'll4ma' environment..."
eval "$(conda shell.bash hook)"
conda activate "$ENV_PREFIX"

# 3. CHPC is Linux/CUDA only — install torch-scatter and spconv with CUDA support.
# CHPC compute nodes run Rocky/RHEL 8 (glibc 2.28), but PyG's recent torch_scatter
# wheels require glibc >=2.32, so prebuilt wheels fail at import time. Build from
# source instead, with CHPC-provided GCC + matching CUDA toolkit modules loaded.
CUDA_TAG=$(python -c "import torch; v=torch.version.cuda or ''; print('cu'+v.replace('.',''))")
echo "Loading gcc/13.3.0 and cuda/12.8.1 modules for source builds..."
module load gcc/13.3.0 cuda/12.8.1

# Pin compilers + CUDA_HOME explicitly. Lmod prepends to PATH, but some setup.py paths
# bypass PATH (e.g. hardcoded /usr/local/cuda) or fall back to /usr/bin/c++ — which on
# RHEL 8 is gcc 8.5, too old for torch 2.8 headers ("need GCC 9 or later").
export CC="$(command -v gcc)"
export CXX="$(command -v g++)"
export CUDA_HOME="${CUDA_HOME:-$(dirname "$(dirname "$(command -v nvcc)")")}"
# Force target compute capabilities. Without this, pytorch3d/torch_scatter setup.py
# auto-detects from torch.cuda.get_device_capability() on the local machine — which on
# a CHPC login node is the GT 1030 display card (sm_61), an arch torch 2.8 has dropped.
# Covers V100/T4/RTX-2080Ti/A100/A40/H100 on CHPC notchpeak; +PTX for forward compat.
export TORCH_CUDA_ARCH_LIST="7.0;7.5;8.0;8.6;9.0+PTX"

echo "Building torch-scatter from source against torch ${CUDA_TAG}..."
python -m pip install --force-reinstall --no-binary torch-scatter torch-scatter
# spconv lags behind torch's CUDA versions. Try the exact match first, then fall
# back to the latest available (cu126 as of 2026-05). CUDA is forward-compatible
# at the driver level, so a cu126 wheel runs fine on a cu128 driver.
echo "Installing spconv (Linux/CHPC)..."
python -m pip install "spconv-${CUDA_TAG}" || python -m pip install spconv-cu126

# pytorch3d: built from source against the active torch/CUDA. The official prebuilt
# wheel index (anaconda 'pytorch3d' channel) tops out at torch 2.4 + cu121, with
# nothing for torch 2.8 / cu128. Reuses the CC/CXX/CUDA_HOME/TORCH_CUDA_ARCH_LIST
# exports above. Build is slow (~15–30 min) and memory-hungry — run on a compute node.
echo "Building pytorch3d from source (this takes 15-30 min)..."
python -m pip install --no-build-isolation "git+https://github.com/facebookresearch/pytorch3d.git@stable"

# NOTE: PointTransformerV3 has an optional flash-attn path (enable_flash=True). We do NOT
# install flash-attn here because (1) hermans rtx6000 nodes are Turing (sm_75), below
# flash-attn 2.x's sm_80 minimum, and (2) the build is RAM-hungry (~10GB/nvcc job).
# Instead, train.py passes enable_flash=False, which uses the vanilla attention path.

# 4. Link ll4ma packages via .pth file (bypasses ROS/Catkin setup.py)
echo "Linking ll4ma packages via Python (.pth files)..."
SITE_PACKAGES=$(python -c "import site; print(site.getsitepackages()[0])")
PTH_FILE="$SITE_PACKAGES/ll4ma.pth"

echo "$REPO_DIR/ll4ma_util/src" > "$PTH_FILE"
echo "$REPO_DIR/ll4ma_relation/src" >> "$PTH_FILE"
echo "$REPO_DIR/ll4ma_tamp/blind_grasping/src" >> "$PTH_FILE"
echo "$REPO_DIR/multisensory_learning/src" >> "$PTH_FILE"
echo "$REPO_DIR/ll4ma_isaac/ll4ma_isaacgym/src" >> "$PTH_FILE"
echo "$REPO_DIR/distribution_planning/src" >> "$PTH_FILE"

# Stub ROS modules so ll4ma_util.ros_util imports without ROS installed.
# (Training pipeline only needs pure-Python helpers from this module.)
echo "Installing ROS module stubs (rospy, rospkg, message packages)..."
cat << 'PYEOF' > "$SITE_PACKAGES/ll4ma_ros_stubs.py"
"""Stub ROS modules for non-ROS conda installs (ll4ma)."""
import sys
from unittest.mock import MagicMock

_STUBS = [
    "rospy", "rospkg",
    "ros_numpy", "ros_numpy.point_cloud2",
    "std_srvs", "std_srvs.srv",
    "sensor_msgs", "sensor_msgs.msg",
    "geometry_msgs", "geometry_msgs.msg",
    "visualization_msgs", "visualization_msgs.msg",
    "tf2_msgs", "tf2_msgs.msg",
    "moveit_msgs", "moveit_msgs.msg",
    "std_msgs", "std_msgs.msg",
    "trajectory_msgs", "trajectory_msgs.msg",
]
for _m in _STUBS:
    sys.modules.setdefault(_m, MagicMock())
PYEOF
echo "import ll4ma_ros_stubs" > "$SITE_PACKAGES/ll4ma_ros_stubs.pth"

echo "==========================================================="
echo "Installation complete!"
echo "Your 'll4ma' environment is ready and your local packages"
echo "are linked natively without using ROS/Catkin."
echo "Repo root: $REPO_DIR"
echo "==========================================================="
