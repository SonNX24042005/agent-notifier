#!/usr/bin/env bash
# Automated Debian/Ubuntu (.deb) package builder for AI Agent Desktop Notifier
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

VERSION="${VERSION:-$(grep -E '^VERSION = ' "$REPO_DIR/bin/anoti" | head -n 1 | cut -d'"' -f2)}"
if [ -z "$VERSION" ]; then
    VERSION="1.3.1"
fi

PACKAGE_NAME="ai-agent-desktop-notifier"
ARCH="all"
DIST_DIR="$REPO_DIR/dist"
BUILD_DIR="$REPO_DIR/build/deb-package"
DEBIAN_DIR="$BUILD_DIR/DEBIAN"
APP_SHARE_DIR="$BUILD_DIR/usr/share/ai-agent-desktop-notifier"
BIN_DIR="$BUILD_DIR/usr/bin"
GNOME_EXT_DIR="$BUILD_DIR/usr/share/gnome-shell/extensions/ai-agent-desktop-notifier@sonnx24042005"

echo "=== Building $PACKAGE_NAME version $VERSION ($ARCH) ==="

rm -rf "$BUILD_DIR"
mkdir -p "$DEBIAN_DIR" "$APP_SHARE_DIR/bin" "$APP_SHARE_DIR/hooks" "$BIN_DIR" "$GNOME_EXT_DIR" "$DIST_DIR"

# 1. Copy application files
cp "$REPO_DIR/bin/multi-desktop-notify.py" "$APP_SHARE_DIR/bin/multi-desktop-notify.py"
cp "$REPO_DIR/bin/anoti" "$APP_SHARE_DIR/bin/anoti"
cp "$REPO_DIR/hooks/"* "$APP_SHARE_DIR/hooks/"

# Copy GNOME Shell extension files
cp "$REPO_DIR/gnome-shell-extension/metadata.json" "$GNOME_EXT_DIR/metadata.json"
cp "$REPO_DIR/gnome-shell-extension/extension-modern.js" "$GNOME_EXT_DIR/extension-modern.js"
cp "$REPO_DIR/gnome-shell-extension/extension-legacy.js" "$GNOME_EXT_DIR/extension-legacy.js"
cp "$REPO_DIR/gnome-shell-extension/extension-modern.js" "$GNOME_EXT_DIR/extension.js"

# 2. Create global CLI launcher /usr/bin/anoti
cat << 'EOF' > "$BIN_DIR/anoti"
#!/usr/bin/env bash
exec /usr/bin/python3 /usr/share/ai-agent-desktop-notifier/bin/anoti "$@"
EOF
chmod 755 "$BIN_DIR/anoti"
chmod 755 "$APP_SHARE_DIR/bin/anoti" "$APP_SHARE_DIR/bin/multi-desktop-notify.py"
chmod 755 "$APP_SHARE_DIR/hooks/"*

# 3. Create DEBIAN/control
cat << EOF > "$DEBIAN_DIR/control"
Package: $PACKAGE_NAME
Version: $VERSION
Section: utils
Priority: optional
Architecture: $ARCH
Maintainer: Nguyen Xuan Son <165804217+SonNX24042005@users.noreply.github.com>
Depends: python3 (>= 3.8), python3-gi, gir1.2-atspi-2.0, xdotool, wmctrl, x11-utils, jq, libnotify-bin, pulseaudio-utils | pipewire-audio | alsa-utils
Homepage: https://github.com/SonNX24042005/agent-notifier
Description: Multi-monitor desktop notification overlay and auto-focus for AI agents
 Fast, non-intrusive multi-monitor desktop notification overlay with automatic
 window focus for AI coding agents (Claude Code, Google Antigravity, OpenAI Codex)
 on Linux.
EOF

# 4. Create DEBIAN/postinst
cat << 'EOF' > "$DEBIAN_DIR/postinst"
#!/usr/bin/env bash
set -e

if [ "$1" = "configure" ]; then
    echo "AI Agent Desktop Notifier da duoc cai dat vao /usr/bin/anoti."
    echo "De lien ket hook voi Claude Code, Antigravity va Codex, hay chay:"
    echo "    anoti setup-hooks"
fi
exit 0
EOF
chmod 755 "$DEBIAN_DIR/postinst"

# 5. Create DEBIAN/prerm
cat << 'EOF' > "$DEBIAN_DIR/prerm"
#!/usr/bin/env bash
set -e
exit 0
EOF
chmod 755 "$DEBIAN_DIR/prerm"

# 6. Build debian package using dpkg-deb
OUTPUT_DEB="$DIST_DIR/${PACKAGE_NAME}_${VERSION}_${ARCH}.deb"
dpkg-deb --build --root-owner-group "$BUILD_DIR" "$OUTPUT_DEB"
echo "[OK] Build completed successfully: $OUTPUT_DEB"
