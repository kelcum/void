#!/bin/bash
# Installs VOID for macOS.
#   curl -fsSL https://raw.githubusercontent.com/kelcum/void/main/install.sh | bash
set -e
REPO_RAW="https://raw.githubusercontent.com/kelcum/void/main"
DEST="$HOME/.void"

if [[ $(uname) != Darwin ]]; then
    echo "  This installer is for macOS. On Windows run install.ps1 - see the README."
    exit 1
fi

mkdir -p "$DEST"
here=$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" 2>/dev/null && pwd || true)
if [[ -f "$here/mac/void.sh" ]]; then
    cp "$here/mac/void.sh" "$DEST/void.sh"
else
    curl -fsSL "$REPO_RAW/mac/void.sh" -o "$DEST/void.sh"
fi
chmod +x "$DEST/void.sh"

# a `void` command: link it into the first writable folder that's already on PATH
BIN=''
for dir in /opt/homebrew/bin /usr/local/bin "$HOME/.local/bin"; do
    if [[ -d $dir && -w $dir ]]; then BIN=$dir; break; fi
done
if [[ -z $BIN ]]; then BIN="$HOME/.local/bin"; mkdir -p "$BIN"; fi
ln -sf "$DEST/void.sh" "$BIN/void"
case ":$PATH:" in
    *":$BIN:"*) ;;
    *) echo "export PATH=\"$BIN:\$PATH\"" >> "$HOME/.zshrc"; NEW_SHELL=1 ;;
esac

# double-clickable launcher on the Desktop
cat > "$HOME/Desktop/VOID.command" <<LAUNCHER
#!/bin/bash
exec "$DEST/void.sh"
LAUNCHER
chmod +x "$HOME/Desktop/VOID.command"

echo ""
echo "  VOID installed."
echo "  Launch it: type  void  in Terminal, or double-click VOID.command on your Desktop."
[[ -n $NEW_SHELL ]] && echo "  (open a new Terminal window first so it picks up the void command)"
echo ""
