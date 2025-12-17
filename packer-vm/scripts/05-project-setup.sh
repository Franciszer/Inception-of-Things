#!/bin/bash
# Run project setup scripts to pre-cache dependencies
# This creates a "golden image" ready for fast deployment during defense

set -euo pipefail

echo "================================"
echo "Running Project Setup Scripts"
echo "================================"

# Clone the repository
REPO_DIR="/home/ychibani/Inception-of-Things"

if [ ! -d "$REPO_DIR" ]; then
    echo "Cloning Inception-of-Things repository..."
    sudo -u ychibani git clone -b frthierr-dev https://github.com/Franciszer/Inception-of-Things.git "$REPO_DIR"
else
    echo "Repository already exists, pulling latest changes..."
    cd "$REPO_DIR"
    sudo -u ychibani git pull
fi

# # Part 1 Setup (commented out for now)
# if [ -f "$REPO_DIR/p1/scripts/setup.sh" ]; then
#     echo "Running P1 setup..."
#     sudo -u ychibani bash "$REPO_DIR/p1/scripts/setup.sh"
# fi

# # Part 2 Setup (commented out for now)
# if [ -f "$REPO_DIR/p2/scripts/setup.sh" ]; then
#     echo "Running P2 setup..."
#     sudo -u ychibani bash "$REPO_DIR/p2/scripts/setup.sh"
# fi

# # Part 3 Setup (commented out for now)
# if [ -f "$REPO_DIR/p3/scripts/setup.sh" ]; then
#     echo "Running P3 setup..."
#     sudo -u ychibani bash "$REPO_DIR/p3/scripts/setup.sh"
# fi

# Bonus Setup
if [ -f "$REPO_DIR/bonus/scripts/setup.sh" ]; then
    echo "Running Bonus setup..."
    sudo -u ychibani bash "$REPO_DIR/bonus/scripts/setup.sh"
else
    echo "WARNING: Bonus setup script not found"
fi

echo "================================"
echo "All project setups complete!"
echo "================================"
echo "Golden image is ready for deployment."
