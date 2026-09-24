#!/usr/bin/env bash
set -e

PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$PROJECT_DIR"

VERSION="$1"
NOTES="${2:-"Bản phát hành cập nhật tính năng và sửa lỗi."}"

if [ -z "$VERSION" ]; then
    echo "❌ Vui lòng nhập phiên bản cần release!"
    echo "👉 Ví dụ: ./release.sh 1.0.1 \"Cập nhật tính năng mới\""
    exit 1
fi

echo "📦 Chuẩn bị phát hành SnapMaster v$VERSION..."

# 1. Cập nhật file VERSION
echo "$VERSION" > "$PROJECT_DIR/VERSION"

# 2. Biên dịch & đóng gói app bundle
./bundle_app.sh "$VERSION"

# 3. Nén file zip cho release
ZIP_NAME="SnapMaster.zip"
echo "🗜️ Đang nén $ZIP_NAME..."
rm -f "$ZIP_NAME"
zip -r -y -q "$ZIP_NAME" "SnapMaster.app"

# 4. Commit & Tag trên Git
echo "🏷️ Đang tạo Git tag v$VERSION..."
git add -A
git commit -m "chore(release): v$VERSION" || true
git tag -fa "v$VERSION" -m "SnapMaster v$VERSION"
git push origin main
git push origin "v$VERSION" --force

# 5. Tạo GitHub Release & Upload Asset thông qua GitHub API
echo "🌐 Đang tạo GitHub Release và upload asset..."
python3 -c '
import subprocess, urllib.request, json, os

version = "'"$VERSION"'"
notes = """'"$NOTES"'"""
zip_file = "SnapMaster.zip"

p = subprocess.Popen(["git", "credential-osxkeychain", "get"], stdin=subprocess.PIPE, stdout=subprocess.PIPE, text=True)
out, _ = p.communicate("protocol=https\nhost=github.com\n")
token = dict(line.split("=", 1) for line in out.splitlines() if "=" in line).get("password")

if not token:
    print("❌ Không tìm thấy token GitHub trong macOS Keychain")
    exit(1)

# 1. Tạo Release
release_payload = json.dumps({
    "tag_name": f"v{version}",
    "name": f"SnapMaster v{version}",
    "body": notes,
    "draft": False,
    "prerelease": False
}).encode()

req = urllib.request.Request(
    "https://api.github.com/repos/lehien69/SnapMaster/releases",
    data=release_payload,
    headers={
        "Authorization": f"Bearer {token}",
        "Accept": "application/vnd.github+json",
        "User-Agent": "SnapMaster-Release",
        "Content-Type": "application/json"
    }
)

try:
    with urllib.request.urlopen(req) as resp:
        release_data = json.loads(resp.read().decode())
        upload_url = release_data.get("upload_url", "").split("{")[0]
        release_id = release_data.get("id")
        html_url = release_data.get("html_url")
        print(f"✅ Đã tạo GitHub Release: {html_url}")
except urllib.error.HTTPError as e:
    err = e.read().decode()
    # Nếu release đã tồn tại, tìm release_id
    req_get = urllib.request.Request(
        f"https://api.github.com/repos/lehien69/SnapMaster/releases/tags/v{version}",
        headers={"Authorization": f"Bearer {token}", "User-Agent": "SnapMaster-Release"}
    )
    with urllib.request.urlopen(req_get) as resp:
        release_data = json.loads(resp.read().decode())
        upload_url = release_data.get("upload_url", "").split("{")[0]
        html_url = release_data.get("html_url")

# 2. Upload Zip Asset
upload_url_with_name = f"{upload_url}?name={zip_file}"
with open(zip_file, "rb") as f:
    zip_data = f.read()

req_upload = urllib.request.Request(
    upload_url_with_name,
    data=zip_data,
    headers={
        "Authorization": f"Bearer {token}",
        "Accept": "application/vnd.github+json",
        "User-Agent": "SnapMaster-Release",
        "Content-Type": "application/zip",
        "Content-Length": str(len(zip_data))
    }
)

with urllib.request.urlopen(req_upload) as resp:
    asset_data = json.loads(resp.read().decode())
    print("✅ Đã upload thành công SnapMaster.zip vào GitHub Release!")
    print(f"🔗 Download URL: {asset_data.get(\"browser_download_url\")}")
'

rm -f "$ZIP_NAME"
echo "🎉 Hoàn tất phát hành SnapMaster v$VERSION!"
