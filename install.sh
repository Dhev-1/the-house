#!/usr/bin/env bash
# Symlink dotfiles into place with GNU Stow.
# Usage: ./install.sh            # stow everything
#        ./install.sh hypr kitty # stow only named packages
set -euo pipefail

cd "$(dirname "$(readlink -f "$0")")"

PACKAGES=(hypr kitty rofi btop dunst gtk kvantum starship)
[ "$#" -gt 0 ] && PACKAGES=("$@")

if ! command -v stow >/dev/null 2>&1; then
  echo "GNU Stow is not installed.  Install it:  sudo pacman -S stow" >&2
  exit 1
fi

echo ":: stowing: ${PACKAGES[*]}"
stow -d home -t "$HOME" --restow "${PACKAGES[@]}"

echo
echo ":: done.  Manual follow-ups:"
echo "   - quickshell (the house) lives at:  $PWD/house"
echo "     the hypr config expects it at ~/cloon/newdot/house; if this repo"
echo "     is elsewhere, update the qs -p path in home/hypr/.config/hypr/*.conf."
