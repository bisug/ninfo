#!/usr/bin/env bash
#
# ninfo installer
#
# Builds ninfo from source and installs it to a bin directory on PATH.
# Falls back to downloading a release binary when a Nim toolchain is
# not available.
#
# Usage:
#   ./install.sh              install to ~/.local/bin (or --prefix dir)
#   ./install.sh --uninstall  remove the installed binary
#
# Environment overrides:
#   PREFIX       installation prefix (default: ~/.local)
#   NIM_BIN      nim binary to use (default: nim)
#
set -euo pipefail

readonly PROGRAM="ninfo"
readonly REPO="bisug/ninfo"
readonly VERSION="0.1.0"
readonly MIN_NIM_MAJOR="2"
readonly MIN_NIM_MINOR="2"

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

info()  { printf '\033[1;34m==>\033[0m %s\n' "$*"; }
warn()  { printf '\033[1;33mWARN:\033[0m %s\n' "$*" >&2; }
error() { printf '\033[1;31mERROR:\033[0m %s\n' "$*" >&2; }
die()   { error "$*"; exit 1; }

command_exists() { command -v "$1" &>/dev/null; }

on_path() {
  case ":$PATH:" in
    *":$1:"*) return 0 ;;
    *)        return 1 ;;
  esac
}

# ---------------------------------------------------------------------------
# Argument parsing
# ---------------------------------------------------------------------------

PREFIX="${PREFIX:-$HOME/.local}"
ACTION="install"
while [[ $# -gt 0 ]]; do
  case "$1" in
    --prefix)  PREFIX="$2"; shift 2 ;;
    --prefix=*) PREFIX="${1#*=}"; shift ;;
    --uninstall) ACTION="uninstall"; shift ;;
    -h|--help)
      sed -n '2,12p' "$0"; exit 0 ;;
    *)
      die "unknown option: $1 (try --help)" ;;
  esac
done

readonly PREFIX ACTION
readonly BINDIR="$PREFIX/bin"
readonly TARGET="$BINDIR/$PROGRAM"

# ---------------------------------------------------------------------------
# Uninstall
# ---------------------------------------------------------------------------

do_uninstall() {
  if [[ ! -e "$TARGET" ]]; then
    warn "$TARGET not found; nothing to uninstall"
    exit 0
  fi
  info "Removing $TARGET"
  rm -f "$TARGET"
  info "Uninstalled $PROGRAM"
}

# ---------------------------------------------------------------------------
# Install from source
# ---------------------------------------------------------------------------

nim_version_ok() {
  local nim_bin="$1" version major minor
  version="$("$nim_bin" --version 2>/dev/null | head -1 | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' | head -1)"
  [[ -z "$version" ]] && return 1
  major="${version%%.*}"
  minor="$(echo "$version" | cut -d. -f2)"
  [[ "$major" -gt "$MIN_NIM_MAJOR" ]] && return 0
  [[ "$major" -eq "$MIN_NIM_MAJOR" && "$minor" -ge "$MIN_NIM_MINOR" ]]
}

install_from_source() {
  local nim_bin="${NIM_BIN:-nim}"

  if ! command_exists "$nim_bin"; then
    for candidate in nim "$HOME/.nimble/bin/nim" /usr/local/bin/nim /opt/nim/bin/nim; do
      if command_exists "$candidate"; then nim_bin="$candidate"; break; fi
    done
  fi

  if ! command_exists "$nim_bin"; then
    warn "Nim not found on this system"
    return 1
  fi

  if ! nim_version_ok "$nim_bin"; then
    warn "Nim >= ${MIN_NIM_MAJOR}.${MIN_NIM_MINOR}.0 required"
    return 1
  fi

  info "Building with $("$nim_bin" --version | head -1)"
  "$nim_bin" c --verbosity:0 --hints:off -d:release -o:"$TARGET" src/ninfo.nim
  info "Installed $PROGRAM to $TARGET"
}

# ---------------------------------------------------------------------------
# Install from release binary
# ---------------------------------------------------------------------------

install_from_release() {
  local arch url tmp
  arch="$(uname -m)"
  case "$arch" in
    x86_64|amd64) arch="amd64" ;;
    aarch64|arm64) arch="arm64" ;;
    *) die "unsupported architecture: $arch" ;;
  esac

  url="https://github.com/$REPO/releases/download/v$VERSION/${PROGRAM}-${VERSION}-linux-${arch}.tar.gz"
  info "Downloading $url"
  tmp="$(mktemp -d)"
  trap 'rm -rf "$tmp"' EXIT

  if command_exists curl; then
    curl -fsSL "$url" -o "$tmp/$PROGRAM.tar.gz"
  elif command_exists wget; then
    wget -qO "$tmp/$PROGRAM.tar.gz" "$url"
  else
    die "neither curl nor wget is available"
  fi

  tar -xzf "$tmp/$PROGRAM.tar.gz" -C "$tmp"
  mkdir -p "$BINDIR"
  mv "$tmp/$PROGRAM" "$TARGET"
  chmod +x "$TARGET"
  info "Installed $PROGRAM $VERSION to $TARGET"
}

# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------

main() {
  if [[ "$ACTION" == "uninstall" ]]; then
    do_uninstall
    exit 0
  fi

  mkdir -p "$BINDIR"

  # Prefer building from source: it matches the local system and needs
  # no network. Fall back to a release binary when Nim is unavailable.
  if ! install_from_source; then
    info "Falling back to prebuilt release binary"
    install_from_release
  fi

  if ! on_path "$BINDIR"; then
    warn "$BINDIR is not on your PATH"
    printf '    export PATH="%s:$PATH"\n' "$BINDIR"
  fi

  info "Verify with: $TARGET --version"
}

main "$@"
