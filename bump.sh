#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PKGBUILD="${SCRIPT_DIR}/PKGBUILD"

# Fetch latest kernel version from source repo Makefile
echo "Checking source repo for latest kernel version..."
NEW_MINOR=$(curl -sf "https://raw.githubusercontent.com/Reinazhard/kernel_x86_laptop/v6.12-sultan/Makefile" | grep -oP '^SUBLEVEL = \K.*') || { echo "Error: Failed to fetch source repo Makefile"; exit 1; }

if [ -z "$NEW_MINOR" ]; then
  echo "Error: No stable 6.12.x release found"
  exit 1
fi

# Fetch latest nvidia-580xx-utils version from CachyOS repo
echo "Checking CachyOS repo for latest nvidia-580xx-utils..."
NEW_NV_VER=$(curl -sfL "https://mirror.cachyos.org/repo/x86_64/cachyos/" | grep -oP 'nvidia-580xx-utils-\K[0-9]+\.[0-9]+\.[0-9]+(?=-[0-9]+-x86_64)' | head -1) || { echo "Error: Failed to fetch CachyOS repo listing"; exit 1; }

if [ -z "$NEW_NV_VER" ]; then
  echo "Error: No nvidia-580xx-utils found in CachyOS repo"
  exit 1
fi

# Read current values
CUR_MINOR=$(grep -oP '^_minor=\K.*' "$PKGBUILD")
CUR_NV_VER=$(grep -oP '^_nv_ver=\K.*' "$PKGBUILD")

echo "Current: kernel 6.12.${CUR_MINOR}, nvidia ${CUR_NV_VER}"
echo "Latest:  kernel 6.12.${NEW_MINOR}, nvidia ${NEW_NV_VER}"

if [ "$CUR_MINOR" = "$NEW_MINOR" ] && [ "$CUR_NV_VER" = "$NEW_NV_VER" ]; then
  echo "Already up to date."
  exit 0
fi

# Update PKGBUILD
sed -i "s/^_minor=.*/_minor=${NEW_MINOR}/" "$PKGBUILD"
sed -i "s/^_nv_ver=.*/_nv_ver=${NEW_NV_VER}/" "$PKGBUILD"
sed -i "s/^pkgrel=.*/pkgrel=1/" "$PKGBUILD"

# Commit
cd "$SCRIPT_DIR"
git add PKGBUILD
git commit -m "linux-86hm: v6.12.${NEW_MINOR} && nvidia=${NEW_NV_VER}"

echo "Bumped to 6.12.${NEW_MINOR} && nvidia=${NEW_NV_VER}"
