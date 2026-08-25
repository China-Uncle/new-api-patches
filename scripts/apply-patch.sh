#!/bin/bash
# Apply new-api patches
# Usage: ./apply-patch.sh [version] [patch_name]
# Example:
#   ./apply-patch.sh v1.0.0-rc.25                # apply all patches
#   ./apply-patch.sh v1.0.0-rc.25 add-channel-key # apply a single patch

set -e

VERSION=${1:-v1.0.0-rc.25}
PATCH_NAME=${2:-}
PATCH_DIR="$(cd "$(dirname "$0")/../patches" && pwd)"
BUILD_DIR="/tmp/new-api-patched"

# Determine target patch file(s)
if [[ -n "$PATCH_NAME" ]]; then
    TARGET_PATCH="$PATCH_DIR/${PATCH_NAME}.patch"
    if [[ ! -f "$TARGET_PATCH" ]]; then
        echo "❌ Patch not found: $TARGET_PATCH"
        echo "   Available: $(ls "$PATCH_DIR" | sed 's/\.patch$//' | tr '\n' ' ')"
        exit 1
    fi
    PATCHES=("$TARGET_PATCH")
else
    PATCHES=("$PATCH_DIR"/*.patch)
fi

echo "📦 Cloning QuantumNous/new-api @ ${VERSION}..."
rm -rf "$BUILD_DIR"
git clone --depth 1 --branch "$VERSION" https://github.com/QuantumNous/new-api.git "$BUILD_DIR"
cd "$BUILD_DIR"

for PATCH in "${PATCHES[@]}"; do
    NAME="$(basename "$PATCH")"
    echo ""
    echo "📝 Applying $NAME ..."
    if git apply --check "$PATCH" 2>/dev/null; then
        git apply "$PATCH"
        echo "✅ $NAME applied successfully"
    else
        echo "⚠️ $NAME doesn't apply cleanly, trying with --reject..."
        git apply --reject "$PATCH" || true
        echo "⚠️ Some hunks may have failed. Check .rej files for manual merge."
        echo "   See docs/ for manual modification points."
    fi
done

echo ""
echo "🔨 Building Docker image..."
docker build -t calciumion/new-api:fix-tools .

echo ""
echo "✅ Done! To deploy:"
echo "   cd /opt/new-api"
echo "   # Edit docker-compose.yml: image: calciumion/new-api:fix-tools"
echo "   docker compose up -d"
