#!/bin/bash
# =============================================================================
# 生成 Sileo/Cydia 可用的 APT repo 元数据
# 用法: ./build_repo.sh <deb文件...>
# 产物在本目录: Packages / Packages.gz / Release
# 把这整个目录用静态 HTTP 托管（如 GitHub Pages / 自建 Nginx），
# 用户在 Sileo 中「添加源」填入 URL 即可安装。
# =============================================================================
set -euo pipefail
cd "$(dirname "$0")"

# 清空旧元数据（保留 .deb）
rm -f Packages Packages.gz Release InRelease

if ! command -v dpkg-scanpackages >/dev/null 2>&1; then
  echo "[ERROR] 缺少 dpkg-scanpackages (macOS: brew install dpkg)" >&2
  exit 1
fi

# 扫描当前目录所有 deb 生成 Packages
dpkg-scanpackages . /dev/null 2>/dev/null > Packages

# 压缩
gzip -9 -c Packages > Packages.gz

# 跨平台取校验和（macOS 与 Linux 命令不同）
md5_of()  { if command -v md5 >/dev/null 2>&1; then md5 -q "$1"; else md5sum "$1" | cut -d' ' -f1; fi; }
sha_of()  { if command -v shasum >/dev/null 2>&1; then shasum -a 256 "$1" | cut -d' ' -f1; else sha256sum "$1" | cut -d' ' -f1; fi; }

# 生成 Release（含校验和，Sileo 需要）
{
  echo "Origin: Jiaying GameHall Repo"
  echo "Label: Jiaying GameHall Repo"
  echo "Suite: stable"
  echo "Codename: stable"
  echo "Architectures: iphoneos-arm iphoneos-arm64"
  echo "Components: main"
  echo "Description: JiayingGameTweak apt repository"
  echo "Date: $(date -Ru)"
  echo "MD5Sum:"
  for f in Packages Packages.gz; do
    echo " $(md5_of "$f") $(wc -c < "$f" | tr -d ' ') $f"
  done
  echo "SHA256:"
  for f in Packages Packages.gz; do
    echo " $(sha_of "$f") $(wc -c < "$f" | tr -d ' ') $f"
  done
} > Release

echo "[OK] repo 元数据已生成:"
ls -la Packages Packages.gz Release
echo ""
echo "下一步: 用 HTTP 托管本目录，然后在 Sileo 添加该 URL 作为源。"
