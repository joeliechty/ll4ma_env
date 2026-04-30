#!/bin/bash

# Define the target directory
TARGET_DIR="$HOME/gitrepos"

# List of repository URLs
REPOS=(
    "git@bitbucket.org:robot-learning/multisensory_learning.git"
    "git@bitbucket.org:robot-learning/ll4ma_util.git"
    "git@bitbucket.org:robot-learning/ll4ma_tamp.git"
    "git@bitbucket.org:robot-learning/ll4ma_relation.git"
    "git@bitbucket.org:robot-learning/ll4ma_isaac.git"
)

# Create directory if it doesn't exist
mkdir -p "$TARGET_DIR"
cd "$TARGET_DIR" || { echo "Failed to enter $TARGET_DIR"; exit 1; }

echo "Checking repositories in $TARGET_DIR..."

for REPO_URL in "${REPOS[@]}"; do
    # Extract the repo name from the URL (e.g., ll4ma_util)
    REPO_NAME=$(basename "$REPO_URL" .git)

    if [ -d "$REPO_NAME" ]; then
        echo " [✓] $REPO_NAME already exists. Skipping."
    else
        echo " [!] $REPO_NAME not found. Cloning..."
        git clone "$REPO_URL"
    fi
done

echo "Done!"