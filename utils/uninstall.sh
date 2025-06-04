#!/bin/bash
# Clean uninstaller for symfony-git-review

set -euo pipefail

INSTALL_DIR="$HOME/.local/bin"
SCRIPT_NAME="symfony-review"
SCRIPT_PATH="$INSTALL_DIR/$SCRIPT_NAME"

echo "🗑️  Uninstalling Symfony Git Review Tool..."

if [ -f "$SCRIPT_PATH" ]; then
    rm "$SCRIPT_PATH"
    echo "✅ Removed $SCRIPT_PATH"
else
    echo "⚠️  Script not found at $SCRIPT_PATH"
fi

echo ""
echo "🧹 Cleanup complete!"
echo "Note: You may want to remove $INSTALL_DIR from your PATH if no longer needed"