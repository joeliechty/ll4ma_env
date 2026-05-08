#!/bin/bash

# CHPC version: repos live in scratch, not $HOME/git_repos
TARGET_DIR="/scratch/general/vast/$USER/latent_dynamics"

REPOS=(
    "git@bitbucket.org:robot-learning/multisensory_learning.git"
    "git@bitbucket.org:robot-learning/ll4ma_util.git"
    "git@bitbucket.org:robot-learning/ll4ma_tamp.git"
    "git@bitbucket.org:robot-learning/ll4ma_relation.git"
    "git@bitbucket.org:robot-learning/ll4ma_isaac.git"
)

run_git_task() {
    "$@"
    local status=$?
    if [ $status -ne 0 ]; then
        echo -e "\n[!] ERROR: Command '$*' failed with exit code $status."
        echo "Check the state of the current repository: $(pwd)"
        exit 1
    fi
}

mkdir -p "$TARGET_DIR"
cd "$TARGET_DIR" || { echo "Failed to enter $TARGET_DIR"; exit 1; }

echo "Checking repositories in $TARGET_DIR..."

for REPO_URL in "${REPOS[@]}"; do
    REPO_NAME=$(basename "$REPO_URL" .git)

    if [ -d "$REPO_NAME" ]; then
        echo ">>> Entering $REPO_NAME..."
    else
        echo ">>> Repository $REPO_NAME not found. Cloning..."
        run_git_task git clone "$REPO_URL"
    fi

    cd "$REPO_NAME" || exit 1

    TARGET_BRANCH="main"
    case "$REPO_NAME" in
        "ll4ma_tamp")
            TARGET_BRANCH="fm_decoder_head"
            ;;
        "ll4ma_util")
            TARGET_BRANCH="joe_fmt"
            ;;
    esac

    echo "Switching to $TARGET_BRANCH..."
    run_git_task git fetch origin
    run_git_task git checkout "$TARGET_BRANCH"
    run_git_task git pull origin "$TARGET_BRANCH"

    cd ..
    echo -e "[✓] $REPO_NAME is ready.\n"
done

echo "All repositories processed successfully!"
