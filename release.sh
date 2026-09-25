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

# Kiểm tra nếu asset đã tồn tại thì xóa trước
assets = release_data.get("assets", [])
for a in assets:
    if a.get("name") == zip_file:
        del_req = urllib.request.Request(
            a.get("url"),
            headers={"Authorization": f"Bearer {token}", "User-Agent": "SnapMaster-Release"},
            method="DELETE"
        )
        try:
            urllib.request.urlopen(del_req)
        except Exception:
            pass

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
    dl_url = asset_data.get("browser_download_url", "")
    print("✅ Đã upload thành công SnapMaster.zip vào GitHub Release!")
    print(f"🔗 Download URL: {dl_url}")

# 3. Tự động cập nhật Homebrew Cask trong lehien69/homebrew-tap
import hashlib, base64

sha256 = hashlib.sha256(zip_data).hexdigest()
print(f"🔑 SHA256 Checksum: {sha256}")

tap_repo = "lehien69/homebrew-tap"
cask_path = "Casks/snapmaster.rb"
cask_api_url = f"https://api.github.com/repos/{tap_repo}/contents/{cask_path}"

req_get_cask = urllib.request.Request(
    cask_api_url,
    headers={
        "Authorization": f"Bearer {token}",
        "Accept": "application/vnd.github+json",
        "User-Agent": "SnapMaster-Release"
    }
)

try:
    cask_sha = None
    try:
        with urllib.request.urlopen(req_get_cask) as resp:
            cask_info = json.loads(resp.read().decode())
            cask_sha = cask_info.get("sha")
    except Exception:
        pass

    cask_content = f"""cask "snapmaster" do
  version "{version}"
  sha256 "{sha256}"

  url "https://github.com/lehien69/SnapMaster/releases/download/v#{{version}}/SnapMaster.zip"
  name "SnapMaster"
  desc "Modern screen capture, annotation, OCR, QR code scanner and screen recording tool for macOS"
  homepage "https://github.com/lehien69/SnapMaster"

  auto_updates true
  depends_on macos: ">= :ventura"

  app "SnapMaster.app"

  postflight do
    system_command "/usr/bin/xattr",
                   args: ["-rd", "com.apple.quarantine", "#{{appdir}}/SnapMaster.app"],
                   must_succeed: false
    system_command "/usr/bin/xattr",
                   args: ["-cr", "#{{appdir}}/SnapMaster.app"],
                   must_succeed: false
  end

  zap trash: [
    "~/Library/Preferences/com.snapmaster.app.plist",
    "~/Library/Application Support/SnapMaster",
  ]
end
"""
    put_payload = {
        "message": f"bump(cask): snapmaster v{version}",
        "content": base64.b64encode(cask_content.encode()).decode()
    }
    if cask_sha:
        put_payload["sha"] = cask_sha

    req_put_cask = urllib.request.Request(
        cask_api_url,
        data=json.dumps(put_payload).encode(),
        method="PUT",
        headers={
            "Authorization": f"Bearer {token}",
            "Accept": "application/vnd.github+json",
            "User-Agent": "SnapMaster-Release",
            "Content-Type": "application/json"
        }
    )
    with urllib.request.urlopen(req_put_cask) as resp:
        print(f"🍺 Đã tự động cập nhật Homebrew Cask v{version} vào {tap_repo}!")
except Exception as e:
    print(f"⚠️ Không thể cập nhật Homebrew Cask tự động: {e}")
'

rm -f "$ZIP_NAME"
echo "🎉 Hoàn tất phát hành SnapMaster v$VERSION!"
