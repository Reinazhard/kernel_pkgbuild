#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

docker run --rm \
  -v "${SCRIPT_DIR}:/pkg" \
  -w /pkg \
  archlinux:base-devel \
  bash -c '
    set -euo pipefail

    # Install dependencies
    pacman -Syu --noconfirm git

    # Create builduser
    useradd -m builduser

    # Allow builduser to run sudo commands without password
    echo "builduser ALL=(ALL) NOPASSWD: ALL" >> /etc/sudoers

    # Fix permissions for the workspace
    chown -R builduser:builduser /pkg

    # Add safe directory for git
    su - builduser -c "git config --global --add safe.directory /pkg"

    # Build package
    su - builduser -c "MAKEFLAGS=\"-j\$(nproc)\" makepkg -s --noconfirm"
  '

echo "Build complete. Packages:"
ls -1 "${SCRIPT_DIR}"/*.pkg.tar.zst 2>/dev/null || echo "No packages found."
