#!/bin/bash

# Define the target directory
TARGET_DIR="$HOME/git_repos/ll4ma"

# List of repository URLs
REPOS=(
    "git@bitbucket.org:robot-learning/multisensory_learning.git"
    "git@bitbucket.org:robot-learning/ll4ma_util.git"
    "git@bitbucket.org:robot-learning/ll4ma_tamp.git"
    "git@bitbucket.org:robot-learning/ll4ma_relation.git"
    "git@bitbucket.org:robot-learning/ll4ma_isaac.git"
    "git@bitbucket.org:robot-learning/distribution_planning.git"
)

# Helper function to run commands and exit on failure
run_git_task() {
    "$@"
    local status=$?
    if [ $status -ne 0 ]; then
        echo -e "\n[!] ERROR: Command '$*' failed with exit code $status."
        echo "Check the state of the current repository: $(pwd)"
        exit 1
    fi
}

# Create directory if it doesn't exist
mkdir -p "$TARGET_DIR"
cd "$TARGET_DIR" || { echo "Failed to enter $TARGET_DIR"; exit 1; }

echo "Checking repositories in $TARGET_DIR..."

for REPO_URL in "${REPOS[@]}"; do
    REPO_NAME=$(basename "$REPO_URL" .git)

    # 1. Clone if missing
    if [ -d "$REPO_NAME" ]; then
        echo ">>> Entering $REPO_NAME..."
    else
        echo ">>> Repository $REPO_NAME not found. Cloning..."
        run_git_task git clone "$REPO_URL"
    fi

    cd "$REPO_NAME" || exit 1

    # 2. Determine the target branch
    TARGET_BRANCH="main" # Default
    case "$REPO_NAME" in
        "ll4ma_tamp")
            TARGET_BRANCH="fm_decoder_head"
            ;;
        "ll4ma_util")
            TARGET_BRANCH="joe_fmt"
            ;;
        "ll4ma_isaac")
            TARGET_BRANCH="sy_container_tactile"
            ;;
    esac

    # 3. Fetch and Switch
    # We use 'run_git_task' to ensure the script stops if the branch doesn't exist 
    # or if there are local conflicts that prevent a checkout/pull.
    echo "Switching to $TARGET_BRANCH..."
    run_git_task git fetch origin
    run_git_task git checkout "$TARGET_BRANCH"
    run_git_task git pull origin "$TARGET_BRANCH"

    # Go back to the parent directory
    cd ..
    echo -e "[✓] $REPO_NAME is ready.\n"
done

echo "All repositories processed successfully!"