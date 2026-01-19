#!/bin/bash
# One-click installer for symfony-git-review

set -euo pipefail

REPO_URL="https://raw.githubusercontent.com/anisajengui/symfony-git-review/main"
INSTALL_DIR="$HOME/.local/bin"
SCRIPT_NAME="symfony-review"

echo "🚀 Installing Symfony Git Review Tool..."

# Create install directory
mkdir -p "$INSTALL_DIR"

# Download main script
echo "📥 Downloading script..."
if curl -sSL "$REPO_URL/symfony-review.sh" -o "$INSTALL_DIR/$SCRIPT_NAME"; then
    chmod +x "$INSTALL_DIR/$SCRIPT_NAME"
    echo "✅ Script installed to $INSTALL_DIR/$SCRIPT_NAME"
else
    echo "❌ Failed to download script"
    exit 1
fi

# Check PATH
if [[ ":$PATH:" != *":$INSTALL_DIR:"* ]]; then
    echo ""
    echo "⚠️  $INSTALL_DIR is not in your PATH"
    echo "Add this line to your ~/.bashrc or ~/.zshrc:"
    echo "export PATH=\"$INSTALL_DIR:\$PATH\""
    echo ""
    echo "Then run: source ~/.bashrc (or ~/.zshrc)"
else
    echo "✅ Installation directory is already in PATH"
fi

echo ""
echo "🎉 Installation complete!"
echo ""
echo "📖 Usage:"
echo "   $SCRIPT_NAME feature/branch-name"
echo "   $SCRIPT_NAME --help"
echo ""
echo "📚 Documentation: https://github.com/anisajengui/symfony-git-review"