#!/bin/bash
# Auto-updater for symfony-git-review

set -euo pipefail

REPO_URL="https://raw.githubusercontent.com/anisajengui/symfony-git-review/main"
INSTALL_DIR="$HOME/.local/bin"
SCRIPT_NAME="symfony-review"
SCRIPT_PATH="$INSTALL_DIR/$SCRIPT_NAME"

echo "🔄 Updating Symfony Git Review Tool..."

if [ ! -f "$SCRIPT_PATH" ]; then
    echo "❌ Script not found at $SCRIPT_PATH"
    echo "Run the installer first: curl -sSL $REPO_URL/utils/install.sh | bash"
    exit 1
fi

# Backup current version
cp "$SCRIPT_PATH" "$SCRIPT_PATH.backup"

# Download latest version
if curl -sSL "$REPO_URL/symfony-review.sh" -o "$SCRIPT_PATH"; then
    chmod +x "$SCRIPT_PATH"
    echo "✅ Updated to latest version"
    rm "$SCRIPT_PATH.backup"
else
    echo "❌ Update failed, restoring backup"
    mv "$SCRIPT_PATH.backup" "$SCRIPT_PATH"
    exit 1
fi

echo "🎉 Update complete!"