#!/bin/bash
# Apply Codex→NVIDIA patch to new-api
# Usage: ./apply-patch.sh [version]
# Example: ./apply-patch.sh v1.0.0-rc.25

set -e

VERSION=${1:-v1.0.0-rc.25}
PATCH_DIR="$(cd "$(dirname "$0")/../patches" && pwd)"
BUILD_DIR="/tmp/new-api-patched"

echo "📦 Cloning QuantumNous/new-api @ ${VERSION}..."
rm -rf "$BUILD_DIR"
git clone --depth 1 --branch "$VERSION" https://github.com/QuantumNous/new-api.git "$BUILD_DIR"
cd "$BUILD_DIR"

echo "📝 Applying patch..."
if git apply --check "$PATCH_DIR/responses-to-chat.patch" 2>/dev/null; then
    git apply "$PATCH_DIR/responses-to-chat.patch"
    echo "✅ Patch applied successfully"
else
    echo "⚠️ Patch doesn't apply cleanly, trying with --reject..."
    git apply --reject "$PATCH_DIR/responses-to-chat.patch" || true
    echo "⚠️ Some hunks may have failed. Check .rej files for manual merge."
    echo "   See: docs/codex-nvidia-fix.md for manual modification points."
fi

echo ""
echo "🔨 Building Docker image..."
docker build -t calciumion/new-api:fix-tools .

echo ""
echo "✅ Done! To deploy:"
echo "   cd /opt/new-api"
echo "   # Edit docker-compose.yml: image: calciumion/new-api:fix-tools"
echo "   docker compose up -d"
