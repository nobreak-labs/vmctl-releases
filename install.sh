#!/usr/bin/env bash
#
# vmctl macOS/Linux installer.
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

case "$(uname -s)" in
    Darwin) OS="macos" ;;
    Linux)  OS="linux" ;;
    *)
        error "This installer supports macOS and Linux only (detected: $(uname -s))."
        exit 1
        ;;
esac

case "$(uname -m)" in
    arm64|aarch64) ARCH="arm64" ;;
    x86_64)        ARCH="amd64" ;;
    *)
        error "Unsupported architecture: $(uname -m)"
        exit 1
        ;;
esac

# 릴리즈 바이너리가 없는 조합은 미리 안내 (Linux는 amd64만 배포)
if [ "$OS" = "linux" ] && [ "$ARCH" != "amd64" ]; then
    error "No linux-${ARCH} binary is published (linux supports amd64 only)."
    exit 1
fi

if ! command -v curl >/dev/null 2>&1; then
    error "curl is required but not found."
    exit 1
fi

info "vmctl installer"

if [ "$VERSION" = "latest" ]; then
    # api.github.com 대신 github.com 리다이렉션을 사용하여 rate limit를 회피합니다.
    latest_url="$(curl -fsSL -o /dev/null -w "%{url_effective}" "https://github.com/$REPO/releases/latest")"
    tag="${latest_url##*/}"
else
    tag="$VERSION"
fi

if [ -z "$tag" ] || [ "$tag" = "latest" ]; then
    error "Could not determine release tag (repo: $REPO, version: $VERSION)"
    exit 1
fi

asset_url="https://github.com/$REPO/releases/download/$tag/vmctl-$tag-${OS}-${ARCH}"

info "Version: $tag"
info "Downloading $(basename "$asset_url")..."

mkdir -p "$INSTALL_DIR"
tmp_path="$(mktemp)"
curl -fsSL -o "$tmp_path" "$asset_url"
chmod +x "$tmp_path"
mv -f "$tmp_path" "$DEST_PATH"

# curl로 받은 파일은 보통 quarantine 속성이 없지만, 혹시 있으면 방어적으로 제거 (macOS 전용)
if [ "$OS" = "macos" ]; then
    xattr -d com.apple.quarantine "$DEST_PATH" >/dev/null 2>&1 || true
fi

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
