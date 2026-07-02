#!/usr/bin/env bash
#
# vmctl macOS installer.
#
# Usage:
#   curl -fsSL https://raw.githubusercontent.com/nobreak-labs/vmctl-releases/main/install.sh | bash
#
# Pin a specific version, or override the source repo / install location via
# environment variables (bash has no param() block, so env vars are the
# equivalent of install.ps1's -Repo/-InstallDir/-Version):
#   VMCTL_VERSION=0.2.0 curl -fsSL .../install.sh | bash
#   VMCTL_REPO="myorg/myrepo" VMCTL_INSTALL_DIR="/usr/local/bin" curl -fsSL .../install.sh | bash
#
# Note: this script installs into the current shell's subprocess, so PATH
# changes only take effect in *new* terminals (or after `source` on the rc
# file printed at the end) — unlike install.ps1's `irm | iex`, `curl | bash`
# cannot modify your interactive shell's environment directly.

set -euo pipefail

# ── 설정 (환경변수로 덮어쓰기 가능) ─────────────────────────────────────────
REPO="${VMCTL_REPO:-nobreak-labs/vmctl-releases}"
INSTALL_DIR="${VMCTL_INSTALL_DIR:-$HOME/.local/bin}"
VERSION="${VMCTL_VERSION:-latest}"
BIN_NAME="vmctl"
# ────────────────────────────────────────────────────────────────────────────

DEST_PATH="$INSTALL_DIR/$BIN_NAME"

info()  { printf '\033[36m%s\033[0m\n' "$1"; }
ok()    { printf '\033[32m%s\033[0m\n' "$1"; }
error() { printf '\033[31m%s\033[0m\n' "$1" >&2; }

if [ "$(uname -s)" != "Darwin" ]; then
    error "This installer is for macOS only (detected: $(uname -s))."
    exit 1
fi

case "$(uname -m)" in
    arm64)  ARCH="arm64" ;;
    x86_64) ARCH="amd64" ;;
    *)
        error "Unsupported architecture: $(uname -m)"
        exit 1
        ;;
esac

if ! command -v curl >/dev/null 2>&1; then
    error "curl is required but not found."
    exit 1
fi

info "vmctl installer"

if [ "$VERSION" = "latest" ]; then
    api_url="https://api.github.com/repos/$REPO/releases/latest"
else
    api_url="https://api.github.com/repos/$REPO/releases/tags/$VERSION"
fi

release_json="$(curl -fsSL -H "User-Agent: vmctl-installer" "$api_url")" || {
    error "Failed to fetch release info from $api_url"
    exit 1
}

tag="$(printf '%s' "$release_json" | grep -m1 '"tag_name"' | sed -E 's/.*"tag_name": *"([^"]+)".*/\1/')"
if [ -z "$tag" ]; then
    error "Could not determine release tag (repo: $REPO, version: $VERSION)"
    exit 1
fi

asset_url="$(printf '%s' "$release_json" \
    | grep -o '"browser_download_url": *"[^"]*"' \
    | sed -E 's/.*"(https:[^"]+)"$/\1/' \
    | grep "vmctl-.*-macos-${ARCH}\$" \
    | head -n1)"

if [ -z "$asset_url" ]; then
    error "No macos-${ARCH} asset found in release '$tag' of $REPO"
    exit 1
fi

info "Version: $tag"
info "Downloading $(basename "$asset_url")..."

mkdir -p "$INSTALL_DIR"
tmp_path="$(mktemp)"
curl -fsSL -o "$tmp_path" "$asset_url"
chmod +x "$tmp_path"
mv -f "$tmp_path" "$DEST_PATH"

# curl로 받은 파일은 보통 quarantine 속성이 없지만, 혹시 있으면 방어적으로 제거
xattr -d com.apple.quarantine "$DEST_PATH" >/dev/null 2>&1 || true

echo
ok "vmctl $tag installed to $DEST_PATH"

case ":$PATH:" in
    *":$INSTALL_DIR:"*)
        echo "Run 'vmctl version' to verify."
        ;;
    *)
        case "${SHELL:-}" in
            */zsh)  profile="$HOME/.zshrc" ;;
            */bash) [ -f "$HOME/.bash_profile" ] && profile="$HOME/.bash_profile" || profile="$HOME/.bashrc" ;;
            *)      profile="$HOME/.profile" ;;
        esac

        path_line="export PATH=\"$INSTALL_DIR:\$PATH\""
        if ! grep -qF "$INSTALL_DIR" "$profile" 2>/dev/null; then
            printf '\n# added by vmctl installer\n%s\n' "$path_line" >> "$profile"
            info "Added $INSTALL_DIR to PATH in $profile"
        fi
        echo "Open a new terminal (or run: source $profile) and run 'vmctl version' to verify."
        ;;
esac
