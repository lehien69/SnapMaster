#!/usr/bin/env bash
set -e

PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$PROJECT_DIR"

COMMIT_MSG="${1:-"update: Code improvement and bug fixes - $(date '+%Y-%m-%d %H:%M:%S')"}"

echo "🚀 Đang tự động đồng bộ code lên GitHub (lehien69/SnapMaster)..."
git add -A

if git diff-index --quiet HEAD --; then
    echo "✨ Không có thay đổi nào mới cần commit."
else
    git commit -m "$COMMIT_MSG"
    git push origin main
    echo "✅ Đã push thành công lên GitHub: https://github.com/lehien69/SnapMaster"
fi
